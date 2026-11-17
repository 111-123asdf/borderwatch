shader_type canvas_item;
render_mode blend_mix;

// Lightweight screen-space atmospheric ColorRect: soft cold-moon vignette + subtle sky sheen.
// Intentionally avoids SCREEN_TEXTURE resampling/offsets so battlefield & HUD text stays 100% sharp.
uniform float vignette_strength : hint_range(0.0, 0.6) = 0.12;
uniform vec4 vignette_color : source_color = vec4(0.04, 0.06, 0.16, 1.0);
uniform float moon_glow_strength : hint_range(0.0, 0.35) = 0.055;
uniform vec4 moon_glow_color : source_color = vec4(0.58, 0.78, 1.0, 1.0);
uniform float breach_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 breach_color : source_color = vec4(0.58, 0.34, 0.94, 1.0);
uniform vec2 breach_uv = vec2(0.92, 0.20);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(0.70, 0.88, 1.0, 1.0);
uniform vec2 focal_uv = vec2(0.5, 0.5);
uniform float focal_pulse : hint_range(0.0, 1.0) = 0.0;

float dither(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

void fragment() {
	// Elliptical edge vignette keeping central 75%+ completely clear for combat & courtyard readability.
	vec2 delta = (UV - vec2(0.5, 0.48)) * vec2(1.0, 1.12);
	float vig = smoothstep(0.50, 0.94, length(delta)) * vignette_strength;

	// Subtle cold-moon atmospheric sheen from upper sky.
	vec2 sky_d = (UV - vec2(0.52, 0.04)) * vec2(0.75, 1.35);
	float sky_glow = exp(-dot(sky_d, sky_d) * 3.2) * moon_glow_strength;

	// Subtle NE rift atmospheric mist when Wave 5+ breach is active.
	vec2 br_d = (UV - breach_uv) * vec2(1.0, 1.4);
	float rift_glow = exp(-dot(br_d, br_d) * 6.5) * breach_intensity * 0.16;

	// Optional brief focal ring pulse on rift breach / bridge gate toggle.
	float ring = 0.0;
	if (focal_pulse > 0.005) {
		float dist = length((UV - focal_uv) * vec2(1.777, 1.0));
		float radius = (1.0 - focal_pulse) * 0.28 + 0.02;
		ring = smoothstep(0.04, 0.0, abs(dist - radius)) * focal_pulse * 0.14;
	}

	float flash = clamp(flash_amount, 0.0, 1.0) * 0.18;

	float total_alpha = vig + sky_glow + rift_glow + ring + flash;
	vec3 accum = vignette_color.rgb * vig
		+ moon_glow_color.rgb * sky_glow
		+ breach_color.rgb * rift_glow
		+ moon_glow_color.rgb * ring
		+ flash_color.rgb * flash;

	vec3 final_rgb = total_alpha > 0.0001 ? accum / total_alpha : vec3(0.0);
	final_rgb += dither(FRAGCOORD.xy) * (1.0 / 255.0);

	COLOR = vec4(final_rgb, clamp(total_alpha * COLOR.a, 0.0, 0.42));
}
