shader_type canvas_item;

uniform float room_seed = 0.0;
uniform vec4 biome_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 mutator_tint : source_color = vec4(0.0, 0.0, 0.0, 0.0);

varying vec2 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	if (tex.a <= 0.01) {
		COLOR = tex;
	} else {
		vec2 cell_uv = v_world_pos / 64.0 + vec2(room_seed * 0.37, room_seed * 0.71);
		float macro_n = value_noise(cell_uv * 0.48);
		float micro_n = value_noise(cell_uv * 2.15);
		float lum_shift = mix(0.90, 1.10, macro_n * 0.65 + micro_n * 0.35);
		vec3 col = tex.rgb * biome_tint.rgb * lum_shift;
		float pulse = 0.55 + 0.45 * sin(TIME * 2.6 + macro_n * 4.0);
		col = mix(col, mutator_tint.rgb, mutator_tint.a * 0.24 * pulse * (0.5 + 0.5 * micro_n));
		COLOR = vec4(col, tex.a);
	}
}
