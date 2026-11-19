shader_type spatial;
render_mode cull_disabled, unshaded;
#include "res://src/map/diorama_common.gdshaderinc"

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
varying vec3 world_normal;
varying vec3 local_pos;
varying float livery_var;
varying float strobe_phase;

void vertex() {
	float t = TIME * motion;
	float half_len = INSTANCE_CUSTOM.r * 1200.0;
	float phi0 = INSTANCE_CUSTOM.g * 6.2831853;
	float omega = max(INSTANCE_CUSTOM.b * 0.25, 0.012);
	livery_var = INSTANCE_CUSTOM.a;
	strobe_phase = phi0 * 3.7;

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

	float vy = alt_drop * (2.0 * sp * cp) * omega;
	float pitch = clamp(atan(vy, speed_xz) * 0.75, -0.22, 0.22);
	float bank = -0.34 * (cp * cp);

	float cam_dist = length(CAMERA_POSITION_WORLD - center_wp);
	float dist_scale = mix(1.0, 2.35, smoothstep(320.0, 2100.0, cam_dist));

	vec3 p = VERTEX * dist_scale;
	vec3 n = NORMAL;

	// Pitch (nose +Z rises when climbing)
	float cpi = cos(pitch);
	float spi = sin(pitch);
	vec3 p1 = vec3(p.x, p.y * cpi + p.z * spi, p.z * cpi - p.y * spi);
	vec3 n1 = vec3(n.x, n.y * cpi + n.z * spi, n.z * cpi - n.y * spi);

	// Bank gently into turn around destination hub
	float cb = cos(bank);
	float sb = sin(bank);
	vec3 p2 = vec3(p1.x * cb - p1.y * sb, p1.x * sb + p1.y * cb, p1.z);
	vec3 n2 = vec3(n1.x * cb - n1.y * sb, n1.x * sb + n1.y * cb, n1.z);

	vec3 wp = center_wp + new_right * p2.x + up0 * p2.y + new_fwd * p2.z;
	world_position = wp;
	world_normal = normalize(new_right * n2.x + up0 * n2.y + new_fwd * n2.z);
	local_pos = VERTEX;

	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(world_normal, 0.0)).xyz;
}

void fragment() {
	// Livery accent per Indonesian carrier (Garuda teal-blue, Merah-Putih crimson, golden amber)
	vec3 accent = livery_var < 0.36
		? vec3(0.06, 0.50, 0.72)
		: (livery_var < 0.72 ? vec3(0.88, 0.18, 0.16) : vec3(0.95, 0.60, 0.12));

	vec3 col = vec3(0.96, 0.97, 0.99); // Gleaming white fuselage
	if (abs(local_pos.x) >= 0.78) {
		col = vec3(0.86, 0.89, 0.93); // Sunlit metallic silver-white wings
		if (local_pos.y < -0.02) {
			col = vec3(0.38, 0.43, 0.50); // Underwing turbofan nacelles
		} else if (abs(local_pos.x) > 5.35 && local_pos.y > 0.60) {
			col = accent; // Upturned carrier winglets
		}
	} else {
		if (local_pos.z > 2.85 && local_pos.z < 4.25 && local_pos.y > 0.35) {
			col = vec3(0.14, 0.22, 0.32); // Cockpit windshield
		} else if (local_pos.z < -2.6 && local_pos.y > 0.72) {
			col = accent; // Tall vertical tail fin livery
		} else if (local_pos.y < 0.18 && local_pos.z > -3.6 && local_pos.z < 3.6) {
			col = mix(vec3(0.84, 0.88, 0.92), accent, 0.28); // Subtle fuselage cheatline/belly
		}
	}

	vec3 L = normalize(sun_dir);
	float diff = mix(0.62, 1.0, abs(dot(normalize(world_normal), L)));
	vec3 lit = mix(ambient_color * 0.92, sun_color * 1.18, diff) * mix(1.0, 0.34, night_factor);
	vec3 final_col = col * lit;

	// Warm cabin glow, red port / green starboard wingtip nav lights, and pulsing white anti-collision strobe
	float t = TIME * motion;
	float strobe = pow(max(0.0, sin(t * 5.2 + strobe_phase)), 16.0);
	float nav_strength = mix(0.25, 1.45, night_factor);
	if (local_pos.x < -4.2) {
		final_col += vec3(1.0, 0.16, 0.12) * nav_strength;
	} else if (local_pos.x > 4.2) {
		final_col += vec3(0.14, 1.0, 0.32) * nav_strength;
	}
	if (abs(local_pos.z) > 4.4 && local_pos.y > 0.6) {
		final_col += vec3(1.0, 0.98, 0.92) * strobe * mix(0.35, 1.8, night_factor);
	}
	if (night_factor > 0.05 && abs(local_pos.x) < 0.85 && local_pos.y > 0.0 && abs(local_pos.z) < 3.4) {
		final_col += vec3(1.0, 0.88, 0.58) * night_factor * 0.42;
	}

	final_col = apply_diorama_fog(final_col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density * 0.85);
	ALBEDO = final_col;
	ROUGHNESS = 0.42;
	SPECULAR = 0.38;
}
