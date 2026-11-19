// Original display-only atmospheric functions; never used by simulation or indicator colors.
float art_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float art_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(art_hash(cell), art_hash(cell + vec2(1.0, 0.0)), u.x),
		mix(art_hash(cell + vec2(0.0, 1.0)), art_hash(cell + vec2(1.0)), u.x), u.y);
}

float art_fbm(vec2 p) {
	float v = 0.62 * art_noise(p);
	v += 0.38 * art_noise(p * 2.13 + vec2(17.3, 9.2));
	return v;
}

float art_fbm3(vec2 p) {
	float v = 0.54 * art_noise(p);
	v += 0.30 * art_noise(p * 2.07 + vec2(17.3, 9.2));
	v += 0.16 * art_noise(p * 4.21 + vec2(5.1, 23.7));
	return v;
}

float cloud_shade(vec2 p, float t, float rain_amt, float drought_amt) {
	float macro_cloud = art_fbm(p / 260.0 + vec2(t * 0.008, t * 0.003));
	float detail_cloud = art_noise(p / 95.0 + vec2(t * 0.014, t * 0.005));
	float cloud = mix(macro_cloud, detail_cloud, 0.25);
	float lo = mix(0.47, 0.31, rain_amt) + drought_amt * 0.14;
	float hi = mix(0.82, 0.70, rain_amt) + drought_amt * 0.10;
	float depth = mix(0.17, 0.28, rain_amt) * (1.0 - drought_amt * 0.45);
	return 1.0 - smoothstep(lo, hi, cloud) * depth;
}

vec3 apply_diorama_fog(vec3 col, vec3 world_pos, vec3 cam_pos, vec3 fog_col, float fog_density) {
	float cam_dist = length(cam_pos - world_pos);
	// Altitude-compensated start ensures orbital national view stays jewel-sharp directly below
	// while distant horizons, oblique mountain ranges and ocean rims fade into atmospheric mist.
	float fog_start = max(420.0, cam_pos.y * 1.26);
	float dist_factor = 1.0 - exp(-max(0.0, cam_dist - fog_start) * fog_density * 1.35);
	float far_rim = smoothstep(2800.0, 6200.0, length(world_pos.xz * vec2(0.55, 1.0)));
	float mix_amt = clamp(max(dist_factor, far_rim * 0.88), 0.0, 0.92);
	return mix(col, fog_col, mix_amt);
}

float region_lift(float id, int selected, float selected_height, int hovered, float hovered_height) {
	int region = int(round(id * 1024.0));
	return region == selected ? selected_height : region == hovered ? hovered_height : 0.0;
}
