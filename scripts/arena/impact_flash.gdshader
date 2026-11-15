shader_type canvas_item;
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 sampled = texture(TEXTURE, UV) * COLOR;
	sampled.rgb = mix(sampled.rgb, vec3(1.0, 0.94, 0.78), flash_strength);
	COLOR = sampled;
}
