shader_type spatial;
render_mode cull_disabled, unshaded;
#include "res://src/map/diorama_common.gdshaderinc"
uniform sampler2D palette : source_color, filter_linear;
uniform bool use_palette = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool foliage = false;
uniform bool is_vehicle = false;
uniform float motion = 1.0;
uniform int selected_region = -1;
uniform float selected_lift = 0.0;
uniform int hovered_region = -1;
uniform float hovered_lift = 0.0;
uniform vec3 sun_dir = vec3(-0.45, 0.80, 0.30);
uniform vec3 sun_color = vec3(1.0, 0.96, 0.88);
uniform vec3 ambient_color = vec3(0.56, 0.68, 0.80);
uniform vec3 fog_color = vec3(0.42, 0.66, 0.80);
uniform float fog_density = 0.00024;
uniform float night_factor = 0.0;
uniform float rain_factor = 0.0;
uniform float drought_factor = 0.0;
varying vec3 world_position;
varying float variation;

void vertex() {
	float lift = region_lift(INSTANCE_CUSTOM.r, selected_region, selected_lift, hovered_region, hovered_lift);
	if (foliage) {
		float phase = INSTANCE_CUSTOM.g * 6.283;
		float gust = (0.7 + 0.3 * sin(TIME * 0.23 + phase)) * mix(1.0, 1.8, rain_factor);
		VERTEX.x += sin(TIME * 0.85 + phase) * max(VERTEX.y, 0.0) * 0.025 * gust * motion;
		VERTEX.z += cos(TIME * 0.65 + phase) * max(VERTEX.y, 0.0) * 0.012 * gust * motion;
	}
	vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
	if (is_vehicle) {
		float v_phase = INSTANCE_CUSTOM.g * 6.283;
		float v_spd = mix(1.1, 2.2, INSTANCE_CUSTOM.b);
		vec3 fwd = normalize(vec3(MODEL_MATRIX[2].x, 0.0, MODEL_MATRIX[2].z));
		float cruise = sin(TIME * v_spd + v_phase) * 0.95 * motion;
		world.xyz += fwd * cruise;
	}
	world.y += lift;
	world_position = world.xyz;
	variation = INSTANCE_CUSTOM.b;
	VERTEX = (inverse(MODEL_MATRIX) * world).xyz;
}

void fragment() {
	vec3 color = tint.rgb;
	if (use_palette) {
		color *= texture(palette, UV).rgb;
	}
	if (foliage) {
		color = mix(color, color * vec3(1.18, 0.94, 0.68), drought_factor * 0.55);
		color = mix(color, color * vec3(0.84, 0.96, 0.86), rain_factor * 0.35);
	}
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 L = normalize(sun_dir);
	float diff = max(0.0, dot(world_normal, L));
	vec3 lit = mix(ambient_color * 0.70, sun_color * 1.05, diff) * mix(1.0, 0.28, night_factor);
	vec3 final_col = color * lit * mix(0.88, 1.12, variation) * cloud_shade(world_position.xz, TIME * motion, rain_factor, drought_factor);

	// Bright warm headlight / streetlight sparkle at night when non-foliage urban props emit light
	if (!foliage && night_factor > 0.02 && dot(color, vec3(0.33)) > 0.62) {
		final_col += vec3(1.0, 0.82, 0.44) * night_factor * 0.55;
	}

	final_col = apply_diorama_fog(final_col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
	ALBEDO = final_col;
	ROUGHNESS = mix(0.92, 0.55, rain_factor * 0.5);
	SPECULAR = 0.14;
}
