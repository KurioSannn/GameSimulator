shader_type spatial;
render_mode cull_disabled, unshaded;
#include "res://src/map/diorama_common.gdshaderinc"

uniform bool is_toll = false;
uniform float base_half_width = 0.65;
uniform float far_scale = 2.4;
uniform float motion = 1.0;
uniform vec3 sun_dir = vec3(-0.36, 0.88, 0.28);
uniform vec3 sun_color = vec3(1.0, 0.96, 0.88);
uniform vec3 ambient_color = vec3(0.56, 0.68, 0.80);
uniform vec3 fog_color = vec3(0.42, 0.66, 0.80);
uniform float fog_density = 0.00024;
uniform float night_factor = 0.0;
uniform float rain_factor = 0.0;
uniform float drought_factor = 0.0;

varying vec3 world_position;
varying float far_blend;
varying float road_dist;
varying float road_across;

void vertex() {
	vec3 center_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float cam_dist = length(CAMERA_POSITION_WORLD - center_world);
	far_blend = smoothstep(260.0, 2000.0, cam_dist);
	float half_w = base_half_width * mix(1.0, far_scale, far_blend);

	vec3 wp = center_world;
	wp.x += UV2.x * half_w;
	wp.z += UV2.y * half_w;
	// Slight altitude-adaptive clearance prevents terrain z-fighting from high orbit
	wp.y += mix(0.0, 0.30, far_blend) + (is_toll ? 0.05 : 0.0);

	world_position = wp;
	road_dist = UV.x;
	road_across = UV.y;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

void fragment() {
	float t = TIME * motion;
	float u = road_dist;
	float v = road_across;
	float mid = abs(v - 0.5) * 2.0; // 0 at center, 1 at curb

	// Close-up asphalt & Indonesian highway markings
	float grain = art_noise(world_position.xz * 2.4);
	vec3 asphalt = is_toll ? vec3(0.18, 0.21, 0.26) : vec3(0.25, 0.27, 0.29);
	asphalt *= mix(0.92, 1.08, grain);
	asphalt = mix(asphalt, asphalt * 0.72, rain_factor * 0.55);

	vec3 curb_col = is_toll ? vec3(0.94, 0.70, 0.22) : vec3(0.68, 0.65, 0.56);
	float curb_band = smoothstep(0.70, 0.82, mid) * (1.0 - smoothstep(0.90, 0.98, mid));
	float outer_case = smoothstep(0.86, 0.96, mid);

	vec3 close_col = mix(asphalt, curb_col, curb_band * (is_toll ? 0.92 : 0.62));
	close_col = mix(close_col, vec3(0.09, 0.11, 0.13), outer_case * 0.82);

	if (is_toll) {
		float med_lines = smoothstep(0.09, 0.02, abs(abs(v - 0.5) - 0.045));
		close_col = mix(close_col, vec3(0.96, 0.92, 0.78), med_lines * 0.85);
	} else {
		float dash = smoothstep(0.42, 0.54, fract(u * 0.45));
		float center_line = smoothstep(0.09, 0.02, mid) * dash;
		close_col = mix(close_col, vec3(0.94, 0.88, 0.64), center_line * 0.80);
	}

	// Orbital strategy-map readability: cohesive cream (Jalan Nasional) & amber-gold (Jalan Tol) with dark casing
	vec3 map_core = is_toll ? vec3(0.96, 0.72, 0.22) : vec3(0.79, 0.71, 0.51);
	vec3 map_case = is_toll ? vec3(0.24, 0.16, 0.06) : vec3(0.18, 0.20, 0.18);
	vec3 far_col = mix(map_core, map_case, smoothstep(0.64, 0.88, mid));

	vec3 base_col = mix(close_col, far_col, far_blend * 0.85);

	vec3 L = normalize(sun_dir);
	float sun_y = clamp(L.y * 0.65 + 0.35, 0.25, 1.0);
	vec3 lit = mix(ambient_color * 0.74, sun_color * 1.04, sun_y) * mix(1.0, 0.26, night_factor);
	vec3 final_col = base_col * lit * cloud_shade(world_position.xz, t, rain_factor, drought_factor);

	// Dual-carriageway animated vehicle flow along real Indonesian roads
	float spd = is_toll ? 2.4 : 1.4;
	float lane_a = smoothstep(0.15, 0.02, abs(v - 0.27));
	float lane_b = smoothstep(0.15, 0.02, abs(v - 0.73));
	float ua = u - t * spd;
	float ub = u + t * spd * 0.92;
	float stream_a = pow(max(0.0, sin(ua * 2.2) * sin(ua * 0.71 + 1.3)), 4.0);
	float stream_b = pow(max(0.0, sin(ub * 2.0 + 1.9) * sin(ub * 0.67 + 0.5)), 4.0);

	// Subtle crisp daytime commuters when zoomed close
	float day_cars = (lane_a * stream_a + lane_b * stream_b) * (1.0 - far_blend) * (1.0 - night_factor);
	final_col = mix(final_col, vec3(0.92, 0.93, 0.90), clamp(day_cars * 0.55, 0.0, 0.55));

	// Radiant night/dusk headlights (forward), crimson taillights (opposite), and tollway streetlamps
	if (night_factor > 0.03) {
		float lamp_glow = is_toll
			? smoothstep(0.85, 0.15, mid) * (0.28 + 0.22 * pow(0.5 + 0.5 * sin(u * 1.6), 4.0))
			: smoothstep(0.75, 0.10, mid) * 0.12;
		vec3 night_emit = vec3(1.0, 0.76, 0.36) * lamp_glow;
		night_emit += vec3(1.0, 0.92, 0.68) * lane_a * stream_a * (is_toll ? 1.15 : 0.75);
		night_emit += vec3(1.0, 0.28, 0.16) * lane_b * stream_b * (is_toll ? 0.95 : 0.60);
		final_col += night_emit * night_factor;
	}

	final_col = apply_diorama_fog(final_col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
	ALBEDO = final_col;
	ROUGHNESS = mix(0.88, 0.35, rain_factor * 0.55);
	SPECULAR = 0.18;
}
