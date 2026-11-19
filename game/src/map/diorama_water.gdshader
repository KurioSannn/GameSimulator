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

float water_height(vec2 p, float t, float chop_fade, float micro_fade) {
	// Rotated dual-domain organic FBM swells (zero periodic straight/diagonal stripes at close zoom)
	vec2 p1 = vec2(p.x * 0.78 - p.y * 0.62, p.x * 0.62 + p.y * 0.78);
	vec2 p2 = vec2(p.x * 0.36 + p.y * 0.93, -p.x * 0.93 + p.y * 0.36);
	float warp_x = art_noise(p * 0.018 + vec2(t * 0.022, -t * 0.016)) * 2.4;
	float warp_y = art_noise(p * 0.018 + vec2(-t * 0.017, t * 0.023) + vec2(11.3, 7.1)) * 2.4;
	float w_swell = art_fbm3(p1 * 0.044 + vec2(warp_x + t * 0.062, warp_y - t * 0.036));
	float w_chop = chop_fade > 0.01 ? art_fbm3(p2 * 0.112 + vec2(-t * 0.088 + warp_y * 0.5, t * 0.058)) * chop_fade : 0.0;
	float w_micro = micro_fade > 0.01 ? art_noise(p * 0.29 + vec2(t * 0.15, -t * 0.12)) * micro_fade : 0.0;
	return w_swell * 0.52 + w_chop * 0.34 + w_micro * 0.16;
}

float sample_edge_smooth(vec2 uv, bool close_view) {
	float c = texture(coast_field, clamp(uv, vec2(0.0), vec2(1.0))).g * 180.0;
	if (!close_view || c > 8.0) {
		return c;
	}
	vec2 texel = vec2(1.25) / vec2(textureSize(coast_field, 0));
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
	float chop_fade = 1.0 - smoothstep(650.0, 2400.0, cam_dist);
	float micro_fade = 1.0 - smoothstep(260.0, 1100.0, cam_dist);

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
	float wave_amp = mix(1.0, 1.42, rain_factor);
	float eps = mix(0.85, 1.65, clamp(cam_dist / 1600.0, 0.0, 1.0));
	float hx_pos = water_height(world_position.xz + vec2(eps, 0.0), t, chop_fade, micro_fade);
	float hx_neg = water_height(world_position.xz - vec2(eps, 0.0), t, chop_fade, micro_fade);
	float hz_pos = water_height(world_position.xz + vec2(0.0, eps), t, chop_fade, micro_fade);
	float hz_neg = water_height(world_position.xz - vec2(0.0, eps), t, chop_fade, micro_fade);
	vec2 g = vec2(hx_pos - hx_neg, hz_pos - hz_neg) / (2.0 * eps);
	g *= surf_calm * wave_amp;

	vec3 N = normalize(vec3(-g.x * 2.2, 1.0, -g.y * 2.2));
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
