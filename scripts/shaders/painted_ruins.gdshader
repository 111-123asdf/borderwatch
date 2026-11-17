shader_type canvas_item;
render_mode unshaded;

uniform float is_ruins = 1.0;

void fragment() {
	// Godot fragment COLOR already contains TEXTURE * vertex tint. Never multiply twice.
	vec4 paint = COLOR;
	vec4 tex_center = texture(TEXTURE, UV);
	vec3 tint_mul = paint.rgb / max(tex_center.rgb, vec3(0.001));
	float luma = dot(paint.rgb, vec3(0.299, 0.587, 0.114));

	// 1. Deep coastal sea & stream detection (blue-dominant water pixels)
	float water_mask = smoothstep(0.015, 0.085, paint.b - max(paint.r, paint.g * 0.92)) * (1.0 - smoothstep(0.52, 0.72, paint.r));

	// 2. Warm brazier flame & sunlit gold astrolabe pulse (ruins)
	float flame_mask = is_ruins * smoothstep(0.18, 0.42, paint.r - paint.b) * smoothstep(0.48, 0.82, paint.r);

	// 3. Calm interior combat-zone micro-noise while preserving outer cliffs/trees, water, flames & road edges
	float arena_x = smoothstep(0.03, 0.13, UV.x) * (1.0 - smoothstep(0.87, 0.97, UV.x));
	float arena_y = smoothstep(0.04, 0.14, UV.y) * (1.0 - smoothstep(0.86, 0.96, UV.y));
	float arena_mask = arena_x * arena_y;
	float quiet = arena_mask * (1.0 - water_mask) * (1.0 - flame_mask * 0.85);
	if (quiet > 0.01) {
		vec2 d = TEXTURE_PIXEL_SIZE * (is_ruins > 0.5 ? 2.2 : 1.8);
		vec3 n0 = texture(TEXTURE, UV + d).rgb;
		vec3 n1 = texture(TEXTURE, UV - d).rgb;
		vec3 macro_rgb = ((n0 + n1) * 0.5) * tint_mul;
		float road_hint = smoothstep(0.045, 0.12, paint.r - paint.b) * smoothstep(0.36, 0.58, luma);
		float non_road = quiet * (1.0 - road_hint * 0.72);
		float smooth_amt = is_ruins > 0.5 ? (0.18 + 0.34 * (1.0 - road_hint)) : (0.14 + 0.24 * (1.0 - road_hint));
		paint.rgb = mix(paint.rgb, macro_rgb, quiet * smooth_amt);
		float qluma = dot(paint.rgb, vec3(0.299, 0.587, 0.114));
		vec3 calm_mid = mix(vec3(qluma), paint.rgb, is_ruins > 0.5 ? 0.74 : 0.82);
		vec3 mid_target = is_ruins > 0.5 ? vec3(0.31, 0.33, 0.39) : vec3(0.24, 0.29, 0.22);
		vec3 compressed = mix(calm_mid, mid_target, is_ruins > 0.5 ? 0.24 : 0.16);
		paint.rgb = mix(paint.rgb, compressed, non_road * (is_ruins > 0.5 ? 0.52 : 0.40));
		paint.rgb = mix(paint.rgb, paint.rgb * 0.94, quiet * road_hint * 0.42);
	}

	if (water_mask > 0.01) {
		float wave_a = sin(UV.x * 110.0 + UV.y * 42.0 + TIME * 1.85);
		float wave_b = cos(UV.x * 68.0 - UV.y * 145.0 - TIME * 1.35);
		float ripple = (wave_a * 0.55 + wave_b * 0.45);
		float spec = smoothstep(0.62, 0.95, ripple);
		float foam = smoothstep(0.32, 0.48, luma) * smoothstep(0.25, 0.85, sin(UV.x * 160.0 + TIME * 2.2) * cos(UV.y * 140.0 - TIME * 1.6));
		paint.rgb += water_mask * (ripple * vec3(0.018, 0.042, 0.062) + spec * vec3(0.085, 0.145, 0.185) + foam * vec3(0.06, 0.09, 0.11));
	}

	if (flame_mask > 0.01) {
		float flicker = 0.5 + 0.5 * sin(TIME * 5.2 + UV.x * 38.0 + UV.y * 29.0);
		paint.rgb += flame_mask * flicker * vec3(0.055, 0.028, 0.006);
	}

	// 4. Subtle drifting cloud & sunbeam dapple across stone ruins
	float sun_dapple = sin(UV.x * 9.0 + UV.y * 6.0 - TIME * 0.28) * cos(UV.x * 5.5 - UV.y * 8.0 + TIME * 0.19);
	paint.rgb *= 1.0 + sun_dapple * 0.018;

	COLOR = paint;
}
