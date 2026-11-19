shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_never;
#include "res://src/map/diorama_common.gdshaderinc"

uniform float motion = 1.0;
uniform vec3 sun_color = vec3(1.0, 0.96, 0.88);
uniform vec3 ambient_color = vec3(0.56, 0.68, 0.80);
uniform vec3 fog_color = vec3(0.42, 0.66, 0.80);
uniform float fog_density = 0.00024;
uniform float night_factor = 0.0;

varying vec3 world_position;
varying float cruise_alpha;

void vertex() {
	float t = TIME * motion;
	float half_len = INSTANCE_CUSTOM.r * 1200.0;
	float phi0 = INSTANCE_CUSTOM.g * 6.2831853;
	float omega = max(INSTANCE_CUSTOM.b * 0.25, 0.012);

	vec3 anchor = MODEL_MATRIX[3].xyz;
	vec3 right0 = normalize(MODEL_MATRIX[0].xyz);
	vec3 fwd0 = normalize(MODEL_MATRIX[2].xyz);
	vec3 up0 = vec3(0.0, 1.0, 0.0);

	float a = max(half_len, 24.0);
	float b = clamp(half_len * 0.11, 14.0, 44.0);
	float phi = phi0 + t * omega;

	float sp = sin(phi);
	float cp = cos(phi);
	float cruise_frac = sp * sp;
	float alt_drop = clamp(anchor.y - 34.0, 16.0, 58.0);
	float alt_off = -alt_drop * (1.0 - cruise_frac);

	vec3 center_wp = anchor + fwd0 * (a * cp) + right0 * (b * sp) + vec3(0.0, alt_off, 0.0);

	float vx_loc = b * cp * omega;
	float vz_loc = -a * sp * omega;
	float speed_xz = max(length(vec2(vx_loc, vz_loc)), 0.001);
	vec2 tang = vec2(vx_loc, vz_loc) / speed_xz;

	vec3 new_fwd = normalize(fwd0 * tang.y + right0 * tang.x);
	vec3 new_right = normalize(right0 * tang.y - fwd0 * tang.x);

	float cam_dist = length(CAMERA_POSITION_WORLD - center_wp);
	float dist_scale = mix(1.0, 2.35, smoothstep(320.0, 2100.0, cam_dist));

	vec3 p = VERTEX * dist_scale;
	vec3 wp = center_wp + new_right * p.x + up0 * p.y + new_fwd * p.z;
	world_position = wp;
	// Contrails condense strongly at high cruise altitude and taper away during takeoff/landing
	cruise_alpha = smoothstep(0.18, 0.65, cruise_frac);

	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

void fragment() {
	if (cruise_alpha < 0.02) {
		discard;
	}
	// UV.x in 0..1 across wingspan (twin contrails at 0.30 & 0.70), UV.y = 0 behind engines -> 1 tail fade
	float trail_l = smoothstep(0.16, 0.0, abs(UV.x - 0.30));
	float trail_r = smoothstep(0.16, 0.0, abs(UV.x - 0.70));
	float twin = max(trail_l, trail_r);
	float fade = smoothstep(0.0, 0.14, UV.y) * smoothstep(1.0, 0.18, UV.y);
	float wisp = art_noise(vec2(UV.x * 8.0, UV.y * 12.0 - TIME * motion * 2.5));
	float alpha = twin * fade * mix(0.65, 1.0, wisp) * cruise_alpha * mix(0.46, 0.22, night_factor);
	if (alpha < 0.015) {
		discard;
	}
	vec3 col = mix(ambient_color * 0.9, sun_color * 1.05, 0.72) * mix(1.0, 0.42, night_factor);
	col = apply_diorama_fog(col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density * 0.85);
	ALBEDO = col;
	ALPHA = alpha;
}
