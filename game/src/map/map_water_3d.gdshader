shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;
// Tabletop ocean shader with subtle surface movement and diorama styling.

uniform vec4 ocean_deep : source_color = vec4(0.06, 0.13, 0.22, 1.0);
uniform vec4 ocean_shallow : source_color = vec4(0.12, 0.24, 0.35, 1.0);
uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	vec2 uv_scaled = UV * 40.0;
	float wave1 = sin(uv_scaled.x * 0.8 + TIME * wave_speed) * cos(uv_scaled.y * 0.8 + TIME * wave_speed * 0.7);
	float wave2 = sin(uv_scaled.x * 1.5 - TIME * wave_speed * 0.9) * cos(uv_scaled.y * 1.3 + TIME * wave_speed * 1.1);
	float wave = (wave1 + wave2) * 0.5;
	
	vec3 color = mix(ocean_deep.rgb, ocean_shallow.rgb, wave * 0.25 + 0.25);
	ALBEDO = color;
	ROUGHNESS = 0.25;
	SPECULAR = 0.5;
	METALLIC = 0.1;
}
