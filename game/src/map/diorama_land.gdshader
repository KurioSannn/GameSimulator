shader_type spatial;
render_mode cull_disabled, unshaded;
#include "res://src/map/diorama_common.gdshaderinc"
uniform sampler2D region_colors : filter_nearest, repeat_disable;
uniform bool landscape = true;
uniform sampler2D coast_field : filter_linear, repeat_disable;
uniform sampler2D detail_field : filter_linear, repeat_disable;
uniform vec4 field_bounds;
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
	vec4 state = texelFetch(region_colors, ivec2(int(UV.x + 0.5), 0), 0);
	if (!landscape) {
		vec3 col = state.rgb;
		if (state.a < 0.75 && state.a > 0.01) {
			float stripe = step(mod(FRAGCOORD.x + FRAGCOORD.y, 7.0), 1.2);
			col *= mix(1.0, 0.62, stripe);
		}
		ALBEDO = col;
		ROUGHNESS = 0.96;
		SPECULAR = 0.1;
	} else {
		vec2 field_uv = clamp((world_position.xz - field_bounds.xy) / field_bounds.zw, vec2(0.0), vec2(1.0));
		float inland = texture(coast_field, field_uv).b;
		vec3 det = texture(detail_field, field_uv).rgb;
		float urban = det.r;
		float biome = det.g;
		float relief = det.b;

		vec2 step_uv = vec2(2.2 / 3072.0, 2.2 / 1344.0);
		float h_l = texture(detail_field, clamp(field_uv - vec2(step_uv.x, 0.0), vec2(0.0), vec2(1.0))).b;
		float h_r = texture(detail_field, clamp(field_uv + vec2(step_uv.x, 0.0), vec2(0.0), vec2(1.0))).b;
		float h_u = texture(detail_field, clamp(field_uv - vec2(0.0, step_uv.y), vec2(0.0), vec2(1.0))).b;
		float h_d = texture(detail_field, clamp(field_uv + vec2(0.0, step_uv.y), vec2(0.0), vec2(1.0))).b;
		vec3 hill_n = normalize(vec3((h_l - h_r) * 5.2, 1.0, (h_u - h_d) * 5.2));
		vec3 L = normalize(sun_dir);
		vec3 V = normalize(CAMERA_POSITION_WORLD - world_position);
		float hill_lit = max(0.0, dot(hill_n, L));
		vec3 light_term = mix(ambient_color * 0.72, sun_color * 1.06, hill_lit);
		// Soft night ambient darkness while keeping island topography legible
		light_term *= mix(1.0, 0.30, night_factor);

		float t = TIME * motion;
		float grain = art_fbm(world_position.xz / 28.0);
		float micro_grain = art_noise(world_position.xz / 7.5);

		vec3 beach = vec3(0.76, 0.71, 0.50);
		vec3 valley_green = vec3(0.32, 0.54, 0.22);
		vec3 rainforest = vec3(0.17, 0.39, 0.16);
		vec3 highland = vec3(0.28, 0.40, 0.25);
		vec3 volcanic_crest = vec3(0.45, 0.46, 0.41);

		// Dry Kemarau parches open valleys & savanna toward warm golden-ochre
		vec3 dry_savanna = vec3(0.55, 0.47, 0.24);
		valley_green = mix(valley_green, dry_savanna, drought_factor * (1.0 - biome * 0.45));
		rainforest = mix(rainforest, vec3(0.27, 0.38, 0.18), drought_factor * 0.55);
		// Rainy season deepens moist emerald lushness
		valley_green = mix(valley_green, vec3(0.20, 0.45, 0.18), rain_factor * 0.45);
		beach = mix(beach, vec3(0.55, 0.50, 0.36), rain_factor * 0.55);

		vec3 ground = mix(valley_green, rainforest, smoothstep(0.25, 0.85, biome));
		ground = mix(ground, highland, smoothstep(0.38, 0.74, relief));
		ground = mix(ground, volcanic_crest, smoothstep(0.72, 0.95, relief));
		ground *= mix(0.89, 1.11, mix(grain, micro_grain, 0.35));

		float shore_blend = smoothstep(0.015, 0.13 + grain * 0.05, inland);
		ground = mix(beach, ground, shore_blend);

		float grid_hint = step(0.84, fract(world_position.x * 0.35)) + step(0.84, fract(world_position.z * 0.35));
		vec3 city_paving = mix(vec3(0.40, 0.42, 0.44), vec3(0.50, 0.50, 0.48), clamp(grid_hint, 0.0, 1.0) * 0.45);
		city_paving *= mix(0.92, 1.08, micro_grain);
		float cam_h = length(CAMERA_POSITION_WORLD - world_position);
		float city_pad = smoothstep(0.10, 0.62, urban);
		vec3 metro_base = mix(city_paving, vec3(0.56, 0.54, 0.49), smoothstep(0.45, 0.90, urban) * mix(0.45, 0.18, smoothstep(500.0, 2400.0, cam_h)));
		ground = mix(ground, metro_base, city_pad * 0.85);

		ground *= mix(light_term, ambient_color * mix(0.95, 0.32, night_factor), city_pad * 0.45);
		// Rain wet ground specular sheen
		if (rain_factor > 0.05) {
			vec3 H = normalize(L + V);
			float wet_spec = pow(max(dot(hill_n, H), 0.0), 28.0) * rain_factor * mix(0.14, 0.30, city_pad);
			ground += sun_color * wet_spec;
		}
		ground *= cloud_shade(world_position.xz, t, rain_factor, drought_factor);

		// Nighttime Indonesian metropolis & arterial road constellation glow
		if (night_factor > 0.02 && urban > 0.08) {
			float artery = step(0.72, fract(world_position.x * 0.42)) + step(0.72, fract(world_position.z * 0.42));
			float block_spark = art_noise(world_position.xz * 0.95);
			float glow_strength = smoothstep(0.12, 0.78, urban) * mix(0.45, 1.35, clamp(artery * 0.45 + block_spark, 0.0, 1.0));
			vec3 city_amber = mix(vec3(1.0, 0.68, 0.28), vec3(1.0, 0.86, 0.55), block_spark);
			ground += city_amber * glow_strength * night_factor * 0.82;
		}

		// Humid tropical highland valley mist in dawn/rainy conditions
		float valley_mist = smoothstep(0.32, 0.78, relief) * art_fbm(world_position.xz * 0.015 + vec2(t * 0.005, 0.0)) * (rain_factor * 0.42 + max(0.0, 0.55 - L.y) * 0.25);
		ground = mix(ground, fog_color, clamp(valley_mist, 0.0, 0.48));
		ground = apply_diorama_fog(ground, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);

		ALBEDO = ground;
		ROUGHNESS = mix(0.95, 0.48, rain_factor * 0.65);
		SPECULAR = mix(0.12, 0.40, rain_factor * 0.6);
	}
}
