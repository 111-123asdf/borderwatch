shader_type canvas_item;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 sampled = texture(TEXTURE, UV) * vertex_tint;
	float luma = dot(sampled.rgb, vec3(0.299, 0.587, 0.114));
	sampled.rgb = mix(sampled.rgb, vec3(luma), 0.16);
	sampled.rgb = mix(sampled.rgb, vec3(0.42, 0.51, 0.31), 0.12);
	COLOR = sampled;
}
