shader_type spatial;
render_mode cull_disabled, unshaded;
#include "res://src/map/diorama_common.gdshaderinc"
uniform sampler2D neighbor_field : filter_linear, repeat_disable;
uniform vec4 neighbor_bounds = vec4(-2900.0, -1400.0, 6200.0, 3200.0);
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
		vec2 f_uv = clamp((world_position.xz - neighbor_bounds.xy) / neighbor_bounds.zw, vec2(0.0), vec2(1.0));
		vec3 nf = texture(neighbor_field, f_uv).rgb;
		float inland = nf.g;
		float relief = nf.b;

		vec2 step_uv = vec2(2.0) / vec2(textureSize(neighbor_field, 0));
		float h_l = texture(neighbor_field, clamp(f_uv - vec2(step_uv.x, 0.0), vec2(0.0), vec2(1.0))).b;
		float h_r = texture(neighbor_field, clamp(f_uv + vec2(step_uv.x, 0.0), vec2(0.0), vec2(1.0))).b;
		float h_u = texture(neighbor_field, clamp(f_uv - vec2(0.0, step_uv.y), vec2(0.0), vec2(1.0))).b;
		float h_d = texture(neighbor_field, clamp(f_uv + vec2(0.0, step_uv.y), vec2(0.0), vec2(1.0))).b;
		vec3 hill_n = normalize(vec3((h_l - h_r) * 4.4, 1.0, (h_u - h_d) * 4.4));

		float macro = art_fbm(world_position.xz / 135.0);
		float grain = art_noise(world_position.xz / 18.0);
		float micro = art_noise(world_position.xz / 5.5);
		float is_south_arid = smoothstep(940.0, 1250.0, world_position.z);

		vec3 beach = mix(vec3(0.66, 0.62, 0.45), vec3(0.74, 0.60, 0.41), is_south_arid);
		vec3 lowland = mix(vec3(0.24, 0.41, 0.23), vec3(0.45, 0.42, 0.27), is_south_arid * 0.85);
		vec3 jungle = mix(vec3(0.18, 0.34, 0.20), vec3(0.37, 0.34, 0.24), is_south_arid * 0.78);
		vec3 mountain = mix(vec3(0.28, 0.37, 0.28), vec3(0.49, 0.39, 0.29), is_south_arid * 0.75);

		vec3 base_day = mix(lowland, jungle, smoothstep(0.25, 0.82, macro));
		base_day = mix(base_day, mountain, smoothstep(0.32, 0.78, relief));
		base_day *= mix(0.90, 1.10, mix(grain, micro, 0.4));
		base_day = mix(beach, base_day, smoothstep(0.008, 0.055 + grain * 0.025, inland));
		base_day = mix(base_day, base_day * vec3(1.16, 0.96, 0.72), drought_factor * 0.45);
		base_day = mix(base_day, base_day * vec3(0.84, 0.95, 0.88), rain_factor * 0.35);

		vec3 L = normalize(sun_dir);
		float diff = max(0.0, dot(hill_n, L));
		vec3 light_term = mix(ambient_color * 0.74, sun_color * 0.98, diff) * mix(1.0, 0.30, night_factor);
		vec3 col = base_day * light_term * cloud_shade(world_position.xz, t, rain_factor, drought_factor);

		// Subtle warm coastal town sparkles at night across Johor/Singapore/Manila/Penang
		if (night_factor > 0.05 && is_south_arid < 0.3 && inland > 0.006 && inland < 0.055) {
			float city_spot = smoothstep(0.74, 0.96, art_noise(world_position.xz * 0.28));
			col += vec3(1.0, 0.78, 0.42) * city_spot * night_factor * 0.55;
		}

		// Gentle aerial perspective veil + smooth horizon dissolve so distant clip edges never show
		float outer_fade = max(smoothstep(-960.0, -1620.0, world_position.z), smoothstep(1380.0, 2050.0, world_position.z));
		col = mix(col, fog_color, clamp(0.16 + outer_fade * 0.84, 0.0, 0.96));
		col = apply_diorama_fog(col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density * 1.10);

		ALBEDO = col;
		ROUGHNESS = mix(0.94, 0.65, rain_factor * 0.5);
		SPECULAR = 0.10;
	}
}
