shader_type spatial;
render_mode cull_disabled, unshaded;
#include "res://src/map/diorama_common.gdshaderinc"

uniform sampler2D palette : source_color, filter_linear;
uniform bool use_palette = false;
uniform vec4 tint : source_color = vec4(1.0);
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
varying vec3 world_normal;
varying float variation;
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
		speed_factor = clamp(length(vec2(vx_loc, vz_loc)) / 3.0, 0.25, 1.0);
	}

	vec3 p = VERTEX;
	vec3 n_loc = NORMAL;
	float wave_amp = mix(1.0, 1.45, rain_factor);
	float roll = sin(t * 1.15 + phi0 * 1.7) * 0.065 * wave_amp * motion;
	float pitch = cos(t * 0.92 + phi0 * 1.3) * 0.045 * wave_amp * motion;
	float bob = sin(t * 1.45 + phi0) * 0.25 * wave_amp * motion;
	p.y += bob + p.x * roll + p.z * pitch;
	p.x -= max(p.y, 0.0) * roll * 0.4;
	p.z -= max(p.y, 0.0) * pitch * 0.35;

	vec3 wp = anchor + offset_world + new_right * (p.x * scale_s) + up0 * (p.y * scale_s) + new_fwd * (p.z * scale_s);
	world_position = wp;
	world_normal = normalize(new_right * n_loc.x + up0 * n_loc.y + new_fwd * n_loc.z);
	variation = fract(phi0 * 1.618);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(world_normal, 0.0)).xyz;
}

void fragment() {
	vec3 color = tint.rgb;
	if (use_palette) {
		color *= texture(palette, UV).rgb;
	}
	vec3 L = normalize(sun_dir);
	float diff = max(0.0, dot(normalize(world_normal), L));
	vec3 lit = mix(ambient_color * 0.78, sun_color * 1.10, diff) * mix(1.0, 0.34, night_factor);
	vec3 final_col = color * lit * mix(0.92, 1.08, variation) * cloud_shade(world_position.xz, TIME * motion, rain_factor, drought_factor);

	// Warm deckhouse & navigation lights on ships at dusk and night
	if (night_factor > 0.04) {
		float deck_band = smoothstep(0.35, 0.95, tint.r * 0.4 + dot(color, vec3(0.33)));
		final_col += vec3(1.0, 0.86, 0.50) * deck_band * night_factor * 0.65;
	}

	final_col = apply_diorama_fog(final_col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
	ALBEDO = final_col;
	ROUGHNESS = mix(0.75, 0.38, rain_factor * 0.4);
	SPECULAR = 0.22;
}
