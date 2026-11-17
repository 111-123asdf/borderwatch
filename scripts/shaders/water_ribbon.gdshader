shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 water_tint : source_color = vec4(0.38, 0.78, 0.96, 0.28);
uniform vec4 foam_tint : source_color = vec4(0.88, 0.97, 1.0, 0.42);
uniform float flow_speed = 1.45;
uniform vec2 flow_dir = vec2(0.0, 1.0);

void fragment() {
	vec2 uv = UV;
	// Soft feathered border so the overlay blends seamlessly into painted riverbanks
	float edge_x = smoothstep(0.0, 0.24, uv.x) * smoothstep(1.0, 0.76, uv.x);
	float edge_y = smoothstep(0.0, 0.14, uv.y) * smoothstep(1.0, 0.86, uv.y);
	float mask = edge_x * edge_y;

	vec2 flow_uv = uv * vec2(3.5, 7.0) - flow_dir * (TIME * flow_speed);
	float w1 = sin(flow_uv.y * 6.283 + sin(flow_uv.x * 4.5 + TIME * 1.2) * 1.4);
	float w2 = cos(flow_uv.x * 9.0 - flow_uv.y * 4.2 + TIME * 1.9);
	float caustics = smoothstep(0.38, 0.88, 0.5 + 0.28 * w1 + 0.22 * w2);
	float streak = smoothstep(0.76, 0.96, sin((uv.x * 5.0 + uv.y * 2.0) * 6.283 - TIME * 2.4) * cos(uv.y * 18.0 - TIME * 3.1));

	vec3 col = mix(water_tint.rgb, foam_tint.rgb, caustics * 0.65 + streak * 0.35);
	float alpha = mask * (water_tint.a * 0.45 + caustics * water_tint.a + streak * foam_tint.a * 0.55);
	COLOR = vec4(col, clamp(alpha, 0.0, 0.55));
}
