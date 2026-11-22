shader_type canvas_item;
uniform vec4 environment_tint : source_color = vec4(1.0);
uniform float saturation = 1.0;
uniform float exposure = 1.0;
uniform float ink_contrast = 1.0;
uniform float contact_shade = 0.10;
uniform float flash_strength = 0.0;
void fragment() {
	vec4 paint = COLOR;
	float luma = dot(paint.rgb,vec3(0.299,0.587,0.114));
	paint.rgb = mix(vec3(luma),paint.rgb,saturation)*environment_tint.rgb*exposure;
	paint.rgb = max(vec3(0.0), (paint.rgb - vec3(0.42)) * ink_contrast + vec3(0.42));
	float contact=smoothstep(0.76,0.97,UV.y);
	paint.rgb*=1.0-contact*contact_shade;
	paint.rgb=mix(paint.rgb,vec3(1.0,0.95,0.83),flash_strength);
	COLOR=paint;
}
