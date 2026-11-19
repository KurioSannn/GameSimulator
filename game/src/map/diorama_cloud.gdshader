shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
#include "res://src/map/diorama_common.gdshaderinc"
uniform float motion = 1.0;
uniform float close_fade_start = 260.0;
uniform float close_fade_end = 1050.0;
uniform vec3 sun_dir = vec3(-0.45, 0.80, 0.30);
uniform vec3 sun_color = vec3(1.0, 0.96, 0.88);
uniform vec3 ambient_color = vec3(0.56, 0.68, 0.80);
uniform vec3 fog_color = vec3(0.42, 0.66, 0.80);
uniform float fog_density = 0.00024;
uniform float rain_factor = 0.0;
uniform float drought_factor = 0.0;
uniform float smoke_factor = 0.0;
varying float cam_fade;
varying float phase;
varying float layer_var;
varying vec3 world_position;

void vertex() {
	float h = CAMERA_POSITION_WORLD.y;
	cam_fade = smoothstep(close_fade_start, close_fade_end, h);
	VERTEX *= mix(0.35, 1.0, cam_fade);
	vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
	phase = INSTANCE_CUSTOM.g * 6.283;
	layer_var = INSTANCE_CUSTOM.b;
	float speed = 0.8 + 0.4 * layer_var;
	world.x += sin(TIME * 0.028 * speed + phase) * 26.0 * motion;
	world.z += cos(TIME * 0.020 * speed + phase) * 10.0 * motion;
	world_position = world.xyz;
	VERTEX = (inverse(MODEL_MATRIX) * world).xyz;
}

void fragment() {
	if (cam_fade < 0.02) {
		discard;
	}
	vec2 p = UV * 2.0 - 1.0;
	float radial = length(p);
	if (radial > 0.96) {
		discard;
	}
	float t = TIME * motion;
	vec2 flow = UV * 3.1 + vec2(phase * 1.7 + t * 0.008, layer_var * 4.3 + t * 0.003);
	float density_noise = art_fbm3(flow);
	float mask = smoothstep(0.95, 0.22, radial);
	// Soft volumetric-look cumulus body weighted cleanly by FBM wisps (zero hard polygon silhouette)
	float shape = mask * smoothstep(0.26 - rain_factor * 0.06, 0.76, density_noise + mask * 0.32);
	float alpha = shape * cam_fade * mix(0.58, 0.76, rain_factor) * (1.0 - drought_factor * 0.40);
	if (alpha < 0.015) {
		discard;
	}

	// 1-tap directional self-shadowing toward current sun azimuth creates puffy 3D depth on flat soft puffs
	vec2 sun_off = normalize(sun_dir.xz + vec2(0.001)) * 0.16;
	float lit_sample = art_fbm(flow + sun_off);
	float thickness = clamp((density_noise - lit_sample) * 2.4 + 0.68, 0.0, 1.0);

	vec3 storm_belly = mix(ambient_color * 0.95, vec3(0.42, 0.50, 0.60), rain_factor * 0.60);
	vec3 sunlit_crest = mix(vec3(1.0, 0.99, 0.97) * sun_color, vec3(0.88, 0.76, 0.62), smoke_factor * 0.42);
	vec3 col = mix(storm_belly, sunlit_crest, mix(0.32, 0.98, thickness));
	col = apply_diorama_fog(col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density * 0.55);

	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 0.88);
}
