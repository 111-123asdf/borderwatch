shader_type canvas_item;
render_mode blend_mix;

// Stage 3 pixel construct shader: emissive rune pulse, frost chill tint, hit flash, and pixel dissolve.
uniform sampler2D emit_tex : hint_default_black, filter_nearest;
uniform vec4 pulse_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.0, 12.0) = 2.6;
uniform float chill_amount : hint_range(0.0, 1.0) = 0.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;

// Compatibility alias for ArenaVisualFeedback + extra tuning uniforms.
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform float emit_strength : hint_range(0.0, 3.0) = 1.25;
uniform float phase_offset : hint_range(0.0, 6.283) = 0.0;
uniform float dissolve_pixel_size : hint_range(1.0, 8.0) = 2.0;
uniform vec4 dissolve_edge_color : source_color = vec4(0.55, 0.88, 1.0, 1.0);
uniform vec4 frost_tint : source_color = vec4(0.45, 0.82, 1.0, 1.0);
uniform vec4 hit_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	if (base.a <= 0.005) {
		COLOR = base;
	} else {
		vec3 col = base.rgb;
		float alpha = base.a;

		// 1. Rune core emissive breathing pulse driven by emit_tex.
		vec4 emit = texture(emit_tex, UV);
		float emit_mask = max(emit.r, max(emit.g, emit.b)) * emit.a;
		if (emit_mask > 0.01) {
			float pulse = 0.72 + 0.36 * sin(TIME * pulse_speed + phase_offset);
			vec3 glow_col = emit.rgb * pulse_color.rgb;
			col += glow_col * emit_mask * pulse * emit_strength;
		}

		// 2. Frost chill / freeze blue shift keeping silhouette and rune cores legible.
		if (chill_amount > 0.001) {
			float lum = dot(col, vec3(0.299, 0.587, 0.114));
			vec3 icy = vec3(lum * 0.72) * frost_tint.rgb * 1.45 + vec3(0.05, 0.16, 0.32);
			float rim_boost = smoothstep(0.35, 0.9, lum) * 0.25;
			col = mix(col, icy + vec3(0.65, 0.90, 1.0) * rim_boost, clamp(chill_amount * 0.78, 0.0, 0.85));
		}

		// 3. Crisp white-gold hit flash (supports both hit_flash and ArenaVisualFeedback.flash_strength).
		float flash = clamp(max(hit_flash, flash_strength), 0.0, 1.0);
		if (flash > 0.001) {
			col = mix(col, hit_color.rgb, flash);
		}

		// 4. Death pixel-block dissolve with glowing cyan-violet ember border.
		if (dissolve_progress > 0.001) {
			vec2 cell = floor(UV / (TEXTURE_PIXEL_SIZE * max(1.0, dissolve_pixel_size)));
			float n = hash21(cell);
			float threshold = dissolve_progress * 1.08;
			if (n < threshold) {
				alpha = 0.0;
			} else if (n < threshold + 0.14) {
				float edge = 1.0 - (n - threshold) / 0.14;
				col = mix(col, dissolve_edge_color.rgb * 1.35, clamp(edge, 0.0, 1.0));
			}
		}

		COLOR = vec4(col, alpha);
	}
}
