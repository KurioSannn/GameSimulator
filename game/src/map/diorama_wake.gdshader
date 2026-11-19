shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_never;
#include "res://src/map/diorama_common.gdshaderinc"

uniform float motion = 1.0;
uniform vec3 sun_color = vec3(1.0, 0.96, 0.88);
uniform vec3 ambient_color = vec3(0.56, 0.68, 0.80);
uniform vec3 fog_color = vec3(0.42, 0.66, 0.80);
uniform float fog_density = 0.00024;
uniform float night_factor = 0.0;
uniform float rain_factor = 0.0;

varying vec3 world_position;
varying float speed_factor;

void vertex() {
	float t = TIME * motion;
	float a = INSTANCE_CUSTOM.r * 64.0;
	float b = INSTANCE_CUSTOM.g * 64.0;
	float phi0 = INSTANCE_CUSTOM.b * 6.2831853;
	float omega = (INSTANCE_CUSTOM.a - 0.5) * 2.0;

	vec3 anchor = MODEL_MATRIX[3].xyz;
	vec3 col_x = MODEL_MATRIX[0].xyz;
	float scale_s = max(length(col_x), 0.0001);
	vec3 right0 = normalize(col_x);
	vec3 fwd0 = normalize(MODEL_MATRIX[2].xyz);
	vec3 up0 = vec3(0.0, 1.0, 0.0);

	vec3 offset_world = vec3(0.0);
	vec3 new_fwd = fwd0;
	vec3 new_right = right0;
	speed_factor = 0.0;

	if (a > 0.5 && abs(omega) > 0.001) {
		float phi = phi0 + t * omega;
		offset_world = fwd0 * (a * cos(phi)) + right0 * (b * sin(phi));
		float vx_loc = b * cos(phi) * omega;
		float vz_loc = -a * sin(phi) * omega;
		vec2 tang = normalize(vec2(vx_loc, vz_loc));
		new_fwd = normalize(fwd0 * tang.y + right0 * tang.x);
		new_right = normalize(right0 * tang.y - fwd0 * tang.x);
		speed_factor = clamp(length(vec2(vx_loc, vz_loc)) / 2.6, 0.30, 1.0);
	}

	vec3 wp = anchor + offset_world + new_right * (VERTEX.x * scale_s) + up0 * (VERTEX.y * scale_s) + new_fwd * (VERTEX.z * scale_s);
	world_position = wp;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

void fragment() {
	if (speed_factor < 0.05) {
		discard;
	}
	float t = TIME * motion;
	// UV.x = 0..1 across width, UV.y = 0 at bow -> 1 trailing behind stern
	float px = UV.x * 2.0 - 1.0;
	float py = UV.y;
	float v_arm = abs(abs(px) - (0.14 + py * 0.64));
	float kelvin = smoothstep(0.18, 0.0, v_arm) * smoothstep(0.05, 0.25, py) * smoothstep(1.0, 0.34, py);
	float stern_wash = smoothstep(0.32, 0.0, abs(px)) * smoothstep(0.24, 0.40, py) * smoothstep(1.0, 0.36, py);
	float n = art_fbm(vec2(px * 6.0, py * 8.5 - t * 3.0));
	float foam = max(kelvin * 0.95, stern_wash * 0.85) * smoothstep(0.20, 0.78, n + 0.28) * speed_factor;
	if (foam < 0.04) {
		discard;
	}
	vec3 foam_col = mix(vec3(0.45, 0.88, 0.94), vec3(0.96, 0.99, 1.0), smoothstep(0.30, 0.88, foam));
	foam_col *= mix(ambient_color * 0.85, sun_color * 1.04, 0.68) * mix(1.0, 0.36, night_factor);
	foam_col = apply_diorama_fog(foam_col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
	ALBEDO = foam_col;
	ALPHA = clamp(foam * 0.82, 0.0, 0.88);
}
