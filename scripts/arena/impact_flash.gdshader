shader_type canvas_item;
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 environment_tint : source_color = vec4(1.0);
uniform float environment_saturation = 1.0;
void fragment() {
	vec4 sampled = COLOR;
	float luma = dot(sampled.rgb,vec3(0.299,0.587,0.114));
	sampled.rgb = mix(vec3(luma),sampled.rgb,environment_saturation)*environment_tint.rgb;
	sampled.rgb = mix(sampled.rgb, vec3(1.0, 0.94, 0.78), flash_strength);
	COLOR = sampled;
}
