shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 focal_uv = vec2(0.5, 0.5);
uniform vec4 veil_color : source_color = vec4(0.03, 0.04, 0.09, 1.0);
uniform vec4 rim_color : source_color = vec4(0.46, 0.88, 1.0, 1.0);
uniform vec4 rim_inner : source_color = vec4(0.76, 0.46, 1.0, 1.0);

void fragment() {
	if (progress <= 0.005) {
		COLOR = vec4(0.0);
	} else {
		vec2 p = UV - focal_uv;
		p.x *= 1.7778;
		float dist = length(p);
		float max_r = 1.45;
		float open_r = max_r * (1.0 - smoothstep(0.0, 0.92, progress));
		float mask = smoothstep(open_r - 0.06, open_r + 0.02, dist);
		float ring = exp(-pow((dist - open_r) / 0.045, 2.0)) * (1.0 - smoothstep(0.85, 1.0, progress));
		float angle = atan(p.y, p.x);
		float rune = 0.72 + 0.28 * sin(angle * 12.0 + TIME * 8.0);
		vec3 glow_col = mix(rim_inner.rgb, rim_color.rgb, 0.5 + 0.5 * sin(angle * 4.0 - TIME * 5.0));
		vec3 final_col = mix(veil_color.rgb, glow_col, clamp(ring * rune * 1.15, 0.0, 1.0));
		float alpha = clamp(max(mask, ring * 0.88), 0.0, 1.0);
		COLOR = vec4(final_col, alpha);
	}
}
