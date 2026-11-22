shader_type canvas_item;
render_mode unshaded;
uniform float water_clock = 0.0;
uniform float animate = 1.0;

void fragment() {
	vec4 painting = COLOR;
	float water = smoothstep(0.075,0.24,min(painting.g,painting.b)-painting.r);
	float foam = sin(UV.x*264.0 + sin(UV.y*145.0)*2.5 - water_clock*1.9);
	float sparkle = sin(UV.y*208.0 + sin(UV.x*72.0)*2.0 - water_clock*2.4);
	COLOR.rgb += vec3(0.32,0.66,0.62)*water*animate*(foam*0.027 + max(0.0,foam*sparkle)*0.045);
}
