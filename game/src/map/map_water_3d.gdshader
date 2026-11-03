shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;
// Vibrant strategy-game tropical ocean shader with animated waves, sun specular, and foam.

uniform vec4 ocean_deep : source_color = vec4(0.05, 0.16, 0.32, 1.0);
uniform vec4 ocean_shallow : source_color = vec4(0.10, 0.42, 0.58, 1.0);
uniform vec4 foam_color : source_color = vec4(0.85, 0.95, 1.0, 0.8);
uniform float wave_speed : hint_range(0.0, 2.0) = 0.6;

void fragment() {
	vec2 uv_scaled1 = UV * 60.0;
	vec2 uv_scaled2 = UV * 35.0;
	
	float w1 = sin(uv_scaled1.x * 0.9 + TIME * wave_speed) * cos(uv_scaled1.y * 0.8 + TIME * wave_speed * 0.8);
	float w2 = sin(uv_scaled2.x * 1.4 - TIME * wave_speed * 0.7) * cos(uv_scaled2.y * 1.2 + TIME * wave_speed * 1.1);
	float wave = (w1 + w2) * 0.5;
	
	vec3 water_col = mix(ocean_deep.rgb, ocean_shallow.rgb, wave * 0.4 + 0.4);
	
	// Caustic glint lines
	float caust = pow(abs(sin(uv_scaled1.x * 2.5 + TIME * 0.5) * cos(uv_scaled1.y * 2.5 - TIME * 0.4)), 4.0) * 0.25;
	water_col += vec3(caust);
	
	ALBEDO = water_col;
	ROUGHNESS = 0.18;
	SPECULAR = 0.65;
	METALLIC = 0.05;
}
