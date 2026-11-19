shader_type spatial;
render_mode cull_back, unshaded;
#include "res://src/map/diorama_common.gdshaderinc"
uniform sampler2D coast_field : filter_linear, repeat_disable;
uniform vec4 field_bounds;
uniform float motion = 1.0;
uniform vec3 sun_dir = vec3(-0.45, 0.80, 0.30);
uniform vec3 sun_color = vec3(1.0, 0.96, 0.88);
uniform vec3 sky_horizon = vec3(0.68, 0.87, 0.96);
uniform vec3 sky_zenith = vec3(0.24, 0.54, 0.82);
uniform vec3 fog_color = vec3(0.42, 0.66, 0.80);
uniform float fog_density = 0.00024;
uniform float night_factor = 0.0;
uniform float rain_factor = 0.0;
uniform float drought_factor = 0.0;
varying vec3 world_position;

vec2 wave_grad(vec2 p, vec2 dir, float freq, float phase, float warp) {
	float angle = dot(p, dir) * freq + phase + warp;
	float c = cos(angle);
	float steep = 1.0 + 0.30 * sin(angle);
	return dir * (c * freq * steep);
}

float sample_edge_smooth(vec2 uv, bool close_view) {
	float c = texture(coast_field, clamp(uv, vec2(0.0), vec2(1.0))).g * 180.0;
	if (!close_view || c > 8.0) {
		return c;
	}
	vec2 texel = vec2(1.4 / 3072.0, 1.4 / 1344.0);
	float s1 = texture(coast_field, clamp(uv + vec2(texel.x, 0.0), vec2(0.0), vec2(1.0))).g * 180.0;
	float s2 = texture(coast_field, clamp(uv - vec2(texel.x, 0.0), vec2(0.0), vec2(1.0))).g * 180.0;
	float s3 = texture(coast_field, clamp(uv + vec2(0.0, texel.y), vec2(0.0), vec2(1.0))).g * 180.0;
	float s4 = texture(coast_field, clamp(uv - vec2(0.0, texel.y), vec2(0.0), vec2(1.0))).g * 180.0;
	return (c * 2.0 + s1 + s2 + s3 + s4) * 0.166667;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 field_uv = (world_position.xz - field_bounds.xy) / field_bounds.zw;
	bool in_bounds = !(any(lessThan(field_uv, vec2(0.0))) || any(greaterThan(field_uv, vec2(1.0))));
	float cam_dist = length(CAMERA_POSITION_WORLD - world_position);
	float edge = in_bounds ? sample_edge_smooth(field_uv, cam_dist < 850.0) : 180.0;

	float t = TIME * motion;
	float chop_fade = 1.0 - smoothstep(750.0, 2600.0, cam_dist);
	float micro_fade = 1.0 - smoothstep(280.0, 1200.0, cam_dist);

	float shelf_warp = (art_fbm(world_position.xz * 0.022 + vec2(4.2, -7.1)) - 0.5) * 9.5;
	float warped_edge = max(0.0, edge + shelf_warp * smoothstep(2.0, 18.0, edge));

	vec3 lagoon = vec3(0.11, 0.65, 0.66);
	vec3 reef_shelf = vec3(0.055, 0.43, 0.55);
	vec3 arch_sea = vec3(0.032, 0.25, 0.40);
	vec3 abyss = vec3(0.015, 0.13, 0.27);

	vec3 water_col = mix(lagoon, reef_shelf, smoothstep(2.5, 22.0, warped_edge));
	water_col = mix(water_col, arch_sea, smoothstep(20.0, 72.0, warped_edge));
	water_col = mix(water_col, abyss, smoothstep(68.0, 175.0, warped_edge));
	water_col = mix(vec3(0.30, 0.72, 0.67), water_col, smoothstep(0.4, 3.8, edge));
	// Rain season shifts ocean waters slightly cooler & choppier; night shifts to deep midnight blue
	water_col = mix(water_col, vec3(0.04, 0.16, 0.24), rain_factor * 0.35);
	water_col *= mix(1.0, 0.34, night_factor);

	float surf_calm = mix(0.45, 1.0, smoothstep(0.5, 10.0, edge));
	float wave_amp = mix(1.0, 1.38, rain_factor);
	float swell_warp = art_noise(world_position.xz * 0.011 + vec2(t * 0.012, -t * 0.008)) * 3.4;
	vec2 g = vec2(0.0);
	g += wave_grad(world_position.xz, normalize(vec2(0.86, 0.51)), 0.068, t * 0.92 * wave_amp, swell_warp) * 0.34;
	g += wave_grad(world_position.xz, normalize(vec2(-0.48, 0.88)), 0.095, -t * 0.78 * wave_amp, swell_warp * 0.8) * 0.28;
	if (chop_fade > 0.01) {
		g += wave_grad(world_position.xz, normalize(vec2(0.71, -0.70)), 0.165, t * 1.35 * wave_amp, swell_warp * 0.5) * (0.26 * chop_fade);
	}
	if (micro_fade > 0.01) {
		g += wave_grad(world_position.xz, normalize(vec2(-0.91, -0.41)), 0.31, -t * 1.85 * wave_amp, 0.0) * (0.17 * micro_fade);
	}
	g *= surf_calm * wave_amp;

	vec3 N = normalize(vec3(-g.x * 3.2, 1.0, -g.y * 3.2));
	vec3 V = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 L = normalize(sun_dir);
	vec3 H = normalize(L + V);
	vec3 R = reflect(-V, N);

	float n_dot_v = max(dot(N, V), 0.0);
	float fresnel = 0.025 + 0.975 * pow(clamp(1.0 - n_dot_v, 0.0, 1.0), 4.4);
	vec3 sky_refl = mix(sky_horizon, sky_zenith, clamp(R.y * 1.35, 0.0, 1.0));

	float shade = cloud_shade(world_position.xz, t, rain_factor, drought_factor);
	float sun_vis = smoothstep(0.84, 0.98, shade) * (1.0 - rain_factor * 0.65);

	float glints_mul = mix(1.45, 0.65, night_factor);
	float spec_tight = micro_fade > 0.01 ? pow(max(dot(N, H), 0.0), 175.0) * glints_mul * micro_fade : 0.0;
	float spec_mid = pow(max(dot(N, H), 0.0), 38.0) * mix(0.11, 0.22, 1.0 - L.y) * chop_fade;
	float sss = pow(clamp(dot(V, -L + N * 0.65), 0.0, 1.0), 3.0) * (1.0 - smoothstep(10.0, 115.0, edge)) * 0.16 * (1.0 - night_factor * 0.75);

	float shallow_zone = (1.0 - smoothstep(4.0, 32.0, edge)) * smoothstep(0.6, 4.0, edge);
	if (shallow_zone > 0.01 && chop_fade > 0.01 && night_factor < 0.85) {
		float reef_shimmer = pow(art_fbm(world_position.xz * 0.16 + vec2(t * 0.06, -t * 0.04) + g * 1.6), 2.4);
		water_col += sun_color * vec3(0.08, 0.16, 0.13) * reef_shimmer * shallow_zone * sun_vis * chop_fade;
	}

	float total_foam = 0.0;
	if (edge < 6.5) {
		float foam_tex = art_fbm(world_position.xz * 0.25 + vec2(t * 0.055, -t * 0.04));
		float edge_jitter = edge + (foam_tex - 0.5) * 1.4;
		float shore_crest = 0.5 + 0.5 * sin(edge_jitter * 0.95 - t * 1.05 + foam_tex * 3.8);
		float shore_foam = (1.0 - smoothstep(0.2, 2.3, edge_jitter)) * smoothstep(0.22, 0.68, foam_tex) * mix(0.75, 0.92, rain_factor);
		float surf_line = smoothstep(0.68, 0.94, shore_crest) * (1.0 - smoothstep(1.2, 5.8, edge_jitter)) * smoothstep(0.32, 0.72, foam_tex) * 0.42;
		total_foam = clamp(shore_foam + surf_line, 0.0, 0.88);
	}

	float coast_ao = mix(0.84, 1.0, smoothstep(0.0, 4.5, edge));

	vec3 base_lit = (water_col + vec3(0.05, 0.20, 0.18) * sss) * coast_ao;
	vec3 surface = mix(base_lit, sky_refl, clamp(fresnel * 0.72, 0.0, 0.78));
	surface += sun_color * (spec_tight + spec_mid) * sun_vis;
	surface *= shade;
	vec3 foam_col = mix(vec3(0.86, 0.95, 0.94) * sun_color, fog_color * 1.15, night_factor * 0.55) * shade;
	surface = mix(surface, foam_col, total_foam);

	surface = apply_diorama_fog(surface, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);

	ALBEDO = surface;
	ROUGHNESS = 0.18;
	SPECULAR = 0.55;
}
