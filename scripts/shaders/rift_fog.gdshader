shader_type canvas_item;

uniform float fog_alpha : hint_range(0.0, 1.0) = 0.92;
uniform vec4 fog_color_deep : source_color = vec4(0.035, 0.04, 0.08, 1.0);
uniform vec4 fog_color_mist : source_color = vec4(0.11, 0.09, 0.22, 1.0);
uniform float time_scale = 0.28;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * time_scale;
	float n1 = vnoise(uv * 5.0 + vec2(t, t * 0.6));
	float n2 = vnoise(uv * 11.0 - vec2(t * 0.8, t * 0.4));
	float swirl = clamp(n1 * 0.62 + n2 * 0.38, 0.0, 1.0);

	vec2 edge = smoothstep(vec2(0.0), vec2(0.12), uv) * smoothstep(vec2(0.0), vec2(0.12), 1.0 - uv);
	float edge_mask = clamp(edge.x * edge.y + 0.25, 0.0, 1.0);
	vec3 col = mix(fog_color_deep.rgb, fog_color_mist.rgb, swirl * 0.65);
	COLOR = vec4(col, fog_alpha * mix(0.65, 1.0, edge_mask) * COLOR.a);
}
