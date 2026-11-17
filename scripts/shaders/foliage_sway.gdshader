shader_type canvas_item;
render_mode blend_mix;

// Vertex wind sway shader for flags, withered grass, glowing crystals, and PropsDetailLayer tilemaps.
uniform sampler2D emit_tex : hint_default_black, filter_nearest;
uniform float sway_speed : hint_range(0.0, 8.0) = 2.2;
uniform float sway_strength : hint_range(0.0, 16.0) = 3.0;
uniform float wind_freq_x : hint_range(0.0, 0.2) = 0.024;
uniform float wind_freq_y : hint_range(0.0, 0.2) = 0.014;
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;
uniform float tile_size_px : hint_range(0.0, 128.0) = 0.0;
uniform float emit_strength : hint_range(0.0, 3.0) = 1.15;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.4;
uniform float gust_boost : hint_range(0.0, 2.0) = 0.0;

varying vec2 v_world_pos;
varying float v_wind;

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_world_pos = wp;
	float speed = sway_speed * (1.0 + gust_boost * 0.45);
	float t = TIME * speed * motion_scale;
	float gust = sin(t + wp.x * wind_freq_x + wp.y * wind_freq_y)
		+ 0.42 * sin(t * 2.07 + wp.x * 0.065);
	v_wind = gust;

	if (tile_size_px <= 0.5) {
		// Standalone sprite/banner/grass/crystal: anchor bottom (UV.y == 1.0) and sway upper vertices.
		float top_weight = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.35);
		float amp = sway_strength * (1.0 + gust_boost * 0.65) * motion_scale;
		VERTEX.x += gust * amp * top_weight;
		VERTEX.y += abs(gust) * amp * 0.14 * top_weight;
	} else {
		// TileMapLayer mode: gentle shared-vertex micro-breeze prevents cracks across neighboring tiles.
		float micro_amp = sway_strength * 0.15 * (1.0 + gust_boost * 0.5) * motion_scale;
		VERTEX.x += gust * micro_amp;
	}
}

void fragment() {
	vec2 sample_uv = UV;
	if (tile_size_px > 0.5) {
		// Per-tile bottom-anchored horizontal pixel wind shear strictly clamped to each atlas tile cell.
		vec2 tex_px = UV / TEXTURE_PIXEL_SIZE;
		vec2 cell_origin = floor(tex_px / tile_size_px) * tile_size_px;
		vec2 in_tile = (tex_px - cell_origin) / tile_size_px;
		float top_weight = pow(clamp(1.0 - in_tile.y, 0.0, 1.0), 1.45);
		float shift_px = floor(v_wind * sway_strength * 0.42 * (1.0 + gust_boost * 0.55) * top_weight * motion_scale + 0.5);
		float min_x = (cell_origin.x + 0.5) * TEXTURE_PIXEL_SIZE.x;
		float max_x = (cell_origin.x + tile_size_px - 0.5) * TEXTURE_PIXEL_SIZE.x;
		sample_uv.x = clamp(UV.x + shift_px * TEXTURE_PIXEL_SIZE.x, min_x, max_x);
	}

	vec4 base = texture(TEXTURE, sample_uv) * COLOR;
	if (base.a <= 0.005) {
		COLOR = base;
	} else {
		vec3 col = base.rgb;
		vec4 emit = texture(emit_tex, sample_uv);
		float emit_mask = max(emit.r, max(emit.g, emit.b)) * emit.a;
		if (emit_mask > 0.01) {
			float pulse = 0.72 + 0.28 * sin(TIME * pulse_speed * motion_scale + v_world_pos.x * 0.02 + v_world_pos.y * 0.02);
			col += emit.rgb * emit_mask * pulse * emit_strength * (1.0 + gust_boost * 0.35);
		}
		COLOR = vec4(col, base.a);
	}
}
