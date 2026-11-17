shader_type canvas_item;
render_mode blend_mix;

// Nighttime abyssal moat water: curved pixel water currents, dual-layer shoreline foam, and cold moonlit glints.
uniform float wave_speed : hint_range(0.0, 4.0) = 1.0;
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;
uniform float foam_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float glint_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float storm_boost : hint_range(0.0, 2.0) = 0.0;
uniform float tile_size_px : hint_range(0.0, 128.0) = 32.0;
uniform vec4 deep_tint : source_color = vec4(0.06, 0.10, 0.22, 1.0);
uniform vec4 mid_tint : source_color = vec4(0.12, 0.22, 0.40, 1.0);
uniform vec4 foam_color : source_color = vec4(0.70, 0.87, 0.98, 1.0);
uniform vec4 glint_color : source_color = vec4(0.88, 0.96, 1.0, 1.0);
uniform vec4 breach_tint : source_color = vec4(0.56, 0.36, 0.88, 1.0);

varying vec2 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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
		float t = TIME * wave_speed * (1.0 + storm_boost * 0.45) * motion_scale;
		// Snap world coords to 2x pixel grid to match 16->32 pixel tiles cleanly.
		vec2 p = floor(v_world_pos * 0.5) * 2.0;

		// Curved horizontal water ripples (no straight diagonal striping).
		float rip1 = sin(p.y * 0.15 + sin(p.x * 0.042 - t * 1.15) * 1.85 - t * 0.9);
		float rip2 = sin(p.y * 0.10 - cos(p.x * 0.062 + t * 0.85) * 1.55 + t * 0.65);
		float wave = 0.5 + 0.5 * (rip1 * 0.58 + rip2 * 0.42);

		// 4-step quantized water depth/ripple shading preserving tile art.
		float band = floor(wave * 3.99) / 3.0;
		vec3 water_tint = mix(deep_tint.rgb, mid_tint.rgb, band);
		vec3 col = mix(base.rgb, base.rgb * 0.68 + water_tint * 0.50, 0.45);

		// Soft open-water wave crests.
		float crest = step(0.86, wave);
		col = mix(col, mix(mid_tint.rgb, foam_color.rgb, 0.25), crest * 0.30);

		if (storm_boost > 0.01) {
			float arc = smoothstep(0.66, 0.95, 0.5 + 0.5 * sin(p.x * 0.055 - t * 2.3 + p.y * 0.045));
			col = mix(col, breach_tint.rgb * 0.72, arc * storm_boost * 0.32);
		}

		// Detect genuine shoreline inside the current tile's atlas cell (zero atlas bleed).
		float shore_hint = 0.0;
		float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
		if (base.a < 0.96) {
			shore_hint = 0.95;
		} else {
			shore_hint = smoothstep(0.32, 0.62, lum);
		}
		if (tile_size_px > 0.5) {
			vec2 tex_px = UV / TEXTURE_PIXEL_SIZE;
			vec2 cell_origin = floor(tex_px / tile_size_px) * tile_size_px;
			vec2 min_uv = (cell_origin + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
			vec2 max_uv = (cell_origin + vec2(tile_size_px - 0.5)) * TEXTURE_PIXEL_SIZE;
			vec2 off = TEXTURE_PIXEL_SIZE * 2.0;
			float a_up = texture(TEXTURE, clamp(UV - vec2(0.0, off.y), min_uv, max_uv)).a;
			float a_dn = texture(TEXTURE, clamp(UV + vec2(0.0, off.y), min_uv, max_uv)).a;
			float a_lf = texture(TEXTURE, clamp(UV - vec2(off.x, 0.0), min_uv, max_uv)).a;
			float a_rt = texture(TEXTURE, clamp(UV + vec2(off.x, 0.0), min_uv, max_uv)).a;
			float min_alpha = min(min(a_up, a_dn), min(a_lf, a_rt));
			shore_hint = max(shore_hint, 1.0 - smoothstep(0.2, 0.95, min_alpha));
		}

		// Dual-layer shoreline foam hugging edges & bright shore tiles.
		if (shore_hint > 0.05) {
			float surge = 0.5 + 0.5 * sin(t * 2.3 + p.x * 0.05 + p.y * 0.04);
			float dither_mask = step(0.45, hash21(floor(p * 0.5) + floor(t * 2.0) * 0.13));
			float foam_outer = step(0.58, shore_hint * (0.72 + surge * 0.34) + rip1 * 0.08);
			float foam_inner = step(0.38, shore_hint * (0.52 + (1.0 - surge) * 0.32) + rip2 * 0.14) * dither_mask;
			col = mix(col, foam_color.rgb * 0.80, clamp(foam_inner * 0.45 * foam_intensity, 0.0, 0.65));
			col = mix(col, foam_color.rgb, clamp(foam_outer * 0.68 * foam_intensity, 0.0, 0.85));
		}

		// Sparse crisp 2x2px cold moonlit glints across the water surface.
		vec2 glint_cell = floor(p / 4.0);
		float glint_seed = hash21(glint_cell);
		float glint_phase = 0.5 + 0.5 * sin(t * 3.0 + glint_seed * 25.13 + p.x * 0.03);
		float glint = step(0.982, glint_seed) * smoothstep(0.74, 0.98, glint_phase);
		col += glint_color.rgb * glint * 0.72 * glint_intensity;

		COLOR = vec4(col, base.a);
	}
}
