shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;
// High-fidelity diorama tabletop ocean: deep tropical sea with sun specular sheen and wave ripples.

uniform vec4 ocean_deep : source_color = vec4(0.04, 0.09, 0.18, 1.0);
uniform vec4 ocean_shallow : source_color = vec4(0.07, 0.22, 0.35, 1.0);
uniform vec4 sun_specular_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float wave_speed : hint_range(0.0, 2.0) = 0.35;

void fragment() {
	// World-space UV ripples (continuous, seamless across vast ocean)
	vec2 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 uv1 = world_pos * 0.003;
	vec2 uv2 = world_pos * 0.007;
	vec2 uv3 = world_pos * 0.015;

	float t = TIME * wave_speed;
	float w1 = sin(uv1.x * 3.1 + uv1.y * 2.2 + t);
	float w2 = cos(uv2.x * 2.7 - uv2.y * 3.4 - t * 0.8);
	float w3 = sin(uv3.x * 4.2 + uv3.y * 3.8 + t * 1.2);
	float wave = (w1 + w2 * 0.5 + w3 * 0.25) * 0.57;

	// Rich deep-water gradient
	vec3 water_color = mix(ocean_deep.rgb, ocean_shallow.rgb, wave * 0.3 + 0.35);

	// Normal perturbation for sun specular glints
	vec3 n = vec3(
		(cos(uv2.x * 3.0 + t) + cos(uv3.x * 5.0 - t)) * 0.08,
		1.0,
		(sin(uv2.y * 3.0 + t) + sin(uv3.y * 5.0 - t)) * 0.08
	);
	NORMAL = normalize(n);

	ALBEDO = water_color;
	ROUGHNESS = 0.15;
	SPECULAR = 0.85;
	METALLIC = 0.10;
}
