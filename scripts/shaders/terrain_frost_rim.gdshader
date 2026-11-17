shader_type canvas_item;
render_mode blend_mix;

// Basalt edge micro-frost shimmer + emit_tex driven leyline breathing pulse.
uniform sampler2D emit_tex : hint_default_black, filter_nearest;
uniform float emit_strength : hint_range(0.0, 3.0) = 1.25;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.2;
uniform float frost_intensity : hint_range(0.0, 1.5) = 0.16;
uniform float shimmer_speed : hint_range(0.0, 5.0) = 1.6;
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;
uniform float tile_size_px : hint_range(0.0, 128.0) = 32.0;
uniform vec2 sanctum_pos = vec2(860.0, 496.0);
uniform vec4 frost_color : source_color = vec4(0.56, 0.72, 0.90, 1.0);
uniform vec4 pulse_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float breach_boost : hint_range(0.0, 2.0) = 0.0;

varying vec2 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	if (base.a <= 0.005) {
		COLOR = base;
	} else {
		vec3 col = base.rgb;
		vec2 p = floor(v_world_pos * 0.5) * 2.0;

		// Clamp neighbor UVs strictly within the tile's atlas cell to prevent atlas bleeding.
		vec2 min_uv = vec2(0.0);
		vec2 max_uv = vec2(1.0);
		if (tile_size_px > 0.5) {
			vec2 tex_px = UV / TEXTURE_PIXEL_SIZE;
			vec2 cell_origin = floor(tex_px / tile_size_px) * tile_size_px;
			min_uv = (cell_origin + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
			max_uv = (cell_origin + vec2(tile_size_px - 0.5)) * TEXTURE_PIXEL_SIZE;
		}

		// Sample only vertical neighbors inside solid pixels to avoid glaring vertical seam/transparent-border lines.
		vec2 step_uv = TEXTURE_PIXEL_SIZE * 2.0;
		vec4 up_px = texture(TEXTURE, clamp(UV - vec2(0.0, step_uv.y), min_uv, max_uv));
		vec4 dn_px = texture(TEXTURE, clamp(UV + vec2(0.0, step_uv.y), min_uv, max_uv));

		float lum_c = dot(base.rgb, vec3(0.299, 0.587, 0.114));
		float lum_u = dot(up_px.rgb, vec3(0.299, 0.587, 0.114));
		float lum_d = dot(dn_px.rgb, vec3(0.299, 0.587, 0.114));

		float internal_bevel = (up_px.a > 0.85 && dn_px.a > 0.85) ? clamp((lum_c - lum_u) * 1.35 + (lum_c - lum_d) * 0.45, 0.0, 0.65) : 0.0;
		float cool_bias = clamp((base.b - base.r) * 1.4 + 0.30, 0.0, 1.0);
		float frost_seed = hash21(floor(p / 2.0));
		float shimmer = 0.65 + 0.35 * sin(TIME * shimmer_speed * motion_scale + frost_seed * 19.7);
		float sparkle = step(0.955, frost_seed) * smoothstep(0.84, 0.99, shimmer);
		float frost_mask = (internal_bevel * cool_bias * 0.42 + sparkle * (0.18 + internal_bevel * 0.40)) * frost_intensity;
		col = mix(col, frost_color.rgb, clamp(frost_mask, 0.0, 0.18));

		// Leyline emissive glow driven by emit_tex with outward radial breathing pulse from central core.
		vec4 emit = texture(emit_tex, UV);
		float emit_mask = max(emit.r, max(emit.g, emit.b)) * emit.a;
		if (emit_mask > 0.01) {
			float dist = length(v_world_pos - sanctum_pos);
			float wave = 0.68 + 0.32 * sin(TIME * pulse_speed * motion_scale - dist * 0.014);
			float surge = 1.0 + breach_boost * 0.75;
			col += emit.rgb * pulse_tint.rgb * emit_mask * wave * emit_strength * surge;
		}

		COLOR = vec4(col, base.a);
	}
}
