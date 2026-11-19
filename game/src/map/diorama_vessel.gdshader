shader_type spatial;
render_mode cull_back, unshaded;
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
varying float variation;

void vertex() {
	float phase = INSTANCE_CUSTOM.g * 6.283;
	float t = TIME * motion;
	float wave_scale = mix(1.0, 1.5, rain_factor);
	float roll = sin(t * 1.45 + phase) * 0.055 * wave_scale;
	float pitch = cos(t * 1.15 + phase * 1.3) * 0.035 * wave_scale;
	float bob = sin(t * 1.6 + phase) * 0.16 * wave_scale * motion;
	float y_roll = VERTEX.y;
	VERTEX.x += y_roll * roll * motion;
	VERTEX.z += y_roll * pitch * motion;
	vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world.y += bob;
	world_position = world.xyz;
	variation = INSTANCE_CUSTOM.b;
	VERTEX = (inverse(MODEL_MATRIX) * world).xyz;
}

void fragment() {
	vec3 color = tint.rgb;
	if (use_palette) {
		color *= texture(palette, UV).rgb;
	}
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 L = normalize(sun_dir);
	float diff = max(0.0, dot(world_normal, L));
	vec3 lit = mix(ambient_color * 0.72, sun_color * 1.05, diff) * mix(1.0, 0.32, night_factor);
	vec3 final_col = color * lit * mix(0.92, 1.08, variation) * cloud_shade(world_position.xz, TIME * motion, rain_factor, drought_factor);

	// Warm navigation & cabin beacon lights at night on sea vessels
	if (night_factor > 0.02 && dot(color, vec3(0.33)) > 0.55) {
		final_col += vec3(1.0, 0.78, 0.38) * night_factor * 0.75;
	}

	final_col = apply_diorama_fog(final_col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
	ALBEDO = final_col;
	ROUGHNESS = 0.65;
	SPECULAR = 0.25;
}
