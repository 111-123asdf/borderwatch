shader_type canvas_item;

uniform float gait = 0.0;
uniform float stride = 0.0;
uniform float gather = 0.0;
uniform float flash = 0.0;
uniform float motion = 1.0;
uniform float abdomen = 0.0;

void vertex() {
	// Feet and antennae flex around the painted body. Adjacent mesh cells
	// share vertices, so the limb motion never opens seams through the shell.
	float foot = smoothstep(0.52, 0.95, UV.y);
	float swing = sin(gait + floor(UV.x * 4.0) * 3.141593);
	VERTEX.x += stride * swing * foot * motion * 4.0;
	VERTEX.y -= stride * max(swing, 0.0) * foot * motion * 4.5;
	float claw = smoothstep(0.53, 0.94, UV.x) * (1.0 - foot * 0.58);
	VERTEX.x += gather * claw * motion * 8.0;
	VERTEX.y -= gather * claw * motion * 7.0;
	float tail = (1.0 - smoothstep(0.13, 0.56, UV.x)) * abdomen;
	VERTEX.y += sin(gait*0.6) * tail * motion * stride * 3.5;
}

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0,0.92,0.72),flash);
}
