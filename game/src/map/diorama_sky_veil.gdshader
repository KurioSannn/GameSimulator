shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
#include "res://src/map/diorama_common.gdshaderinc"
uniform float motion = 1.0;
uniform vec3 sun_dir = vec3(-0.45, 0.80, 0.30);
uniform vec3 sun_color = vec3(1.0, 0.96, 0.88);
uniform vec3 ambient_color = vec3(0.56, 0.68, 0.80);
uniform vec3 fog_color = vec3(0.42, 0.66, 0.80);
uniform float rain_factor = 0.0;
uniform float drought_factor = 0.0;
uniform float smoke_factor = 0.0;
uniform float layer_height_scale = 1.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float alt_fade = smoothstep(540.0, 1450.0, CAMERA_POSITION_WORLD.y);
	if (alt_fade < 0.01) {
		discard;
	}
	float t = TIME * motion;
	vec2 drift_uv = world_position.xz / (260.0 * layer_height_scale) + vec2(t * 0.008, t * 0.003);
	float f1 = art_fbm3(drift_uv);
	float f2 = art_fbm(drift_uv * 2.15 - vec2(t * 0.004, 11.4));
	float wisp = mix(f1, f2, 0.36);

	float is_cirrus = step(1.2, layer_height_scale);
	// Distinct cloud fronts with clear ocean windows; rainy monsoon expands bands without greying whole map
	float threshold_lo = mix(0.60, 0.51, rain_factor) + drought_factor * 0.12 + is_cirrus * 0.06;
	float threshold_hi = mix(0.86, 0.78, rain_factor) + drought_factor * 0.08 + is_cirrus * 0.05;
	float cloud = smoothstep(threshold_lo, threshold_hi, wisp);
	if (cloud < 0.015) {
		discard;
	}

	// Self-shadow offset toward active sun direction
	vec2 shadow_uv = drift_uv + normalize(sun_dir.xz + vec2(0.001)) * 0.14;
	float sunlit = clamp((wisp - art_fbm(shadow_uv)) * 2.6 + 0.66, 0.0, 1.0);

	float edge_fade = 1.0 - smoothstep(2400.0, 3800.0, length(world_position.xz * vec2(0.55, 1.0)));
	vec3 shadow_col = mix(ambient_color * 0.95, vec3(0.45, 0.53, 0.62), rain_factor * 0.55);
	vec3 crest_col = mix(vec3(1.0, 0.99, 0.97) * sun_color, vec3(0.90, 0.78, 0.60), smoke_factor * 0.45);
	vec3 cloud_col = mix(shadow_col, crest_col, sunlit);
	cloud_col = mix(cloud_col, fog_color, 0.12);

	float base_op = mix(0.42, 0.56, rain_factor) * (1.0 - drought_factor * 0.45);
	float opacity = base_op * mix(1.0, 0.52, is_cirrus);
	ALBEDO = cloud_col;
	ALPHA = cloud * alt_fade * edge_fade * opacity;
}
