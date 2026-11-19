shader_type spatial;
render_mode cull_disabled, unshaded;
#include "res://src/map/diorama_common.gdshaderinc"
uniform bool landscape = true;
uniform float motion = 1.0;
uniform vec3 sun_dir = vec3(-0.45, 0.80, 0.30);
uniform vec3 sun_color = vec3(1.0, 0.96, 0.88);
uniform vec3 ambient_color = vec3(0.56, 0.68, 0.80);
uniform vec3 fog_color = vec3(0.42, 0.66, 0.80);
uniform float fog_density = 0.00024;
uniform float night_factor = 0.0;
uniform float rain_factor = 0.0;
uniform float drought_factor = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (!landscape) {
		ALBEDO = mix(vec3(0.11, 0.22, 0.30), fog_color, 0.35);
		ROUGHNESS = 0.98;
	} else {
		float t = TIME * motion;
		float macro = art_fbm(world_position.xz / 140.0);
		float grain = art_noise(world_position.xz / 24.0);
		// Soft muted olive-sage backdrop landmass so Indonesia remains crisp focal centerpiece
		vec3 base_day = mix(vec3(0.24, 0.36, 0.24), vec3(0.32, 0.42, 0.27), macro);
		base_day = mix(base_day, vec3(0.42, 0.39, 0.27), drought_factor * 0.42);
		base_day *= mix(0.92, 1.08, grain);

		vec3 L = normalize(sun_dir);
		vec3 light_term = mix(ambient_color * 0.72, sun_color * 0.96, max(0.0, L.y * 0.65 + 0.35));
		light_term *= mix(1.0, 0.28, night_factor);
		vec3 col = base_day * light_term * cloud_shade(world_position.xz, t, rain_factor, drought_factor);

		// Extra atmospheric haze depth over outer neighbor landmasses
		col = mix(col, fog_color, 0.26);
		col = apply_diorama_fog(col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density * 1.15);

		ALBEDO = col;
		ROUGHNESS = 0.96;
		SPECULAR = 0.08;
	}
}
