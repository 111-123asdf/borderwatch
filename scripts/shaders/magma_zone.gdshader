shader_type canvas_item;

uniform float fade : hint_range(0.0, 1.0) = 1.0;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
	           mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.y *= 1.35;
	float r = length(p) * 2.0;
	if (r > 1.0) {
		COLOR = vec4(0.0);
	} else {
		float t = TIME * 1.6;
		float crack = n2(UV * 12.0 + vec2(t * 0.4, -t * 0.5)) * 0.6 + n2(UV * 24.0 - vec2(t * 0.3, t * 0.4)) * 0.4;
		float hot = smoothstep(0.46, 0.78, crack + (1.0 - r) * 0.25);
		float edge = smoothstep(1.0, 0.68, r);
		vec3 crust = vec3(0.22, 0.06, 0.04);
		vec3 flame = vec3(1.0, 0.36, 0.08);
		vec3 core = vec3(1.0, 0.88, 0.36);
		vec3 col = mix(crust, flame, smoothstep(0.18, 0.55, hot));
		col = mix(col, core, smoothstep(0.65, 0.96, hot));
		COLOR = vec4(col, edge * fade * mix(0.62, 0.95, hot));
	}
}
