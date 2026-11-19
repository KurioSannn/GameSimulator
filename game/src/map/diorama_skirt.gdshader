shader_type spatial;
render_mode cull_disabled, unshaded;
#include "res://src/map/diorama_common.gdshaderinc"

uniform bool landscape = true;
uniform vec3 sun_dir = vec3(-0.36, 0.88, 0.28);
uniform vec3 sun_color = vec3(1.0, 0.96, 0.88);
uniform vec3 ambient_color = vec3(0.56, 0.68, 0.80);
uniform vec3 fog_color = vec3(0.42, 0.66, 0.80);
uniform float fog_density = 0.00024;
uniform float night_factor = 0.0;
uniform float rain_factor = 0.0;
uniform float drought_factor = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (!landscape) {
		discard;
	}
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 L = normalize(sun_dir);
	float diff = mix(0.42, 0.95, abs(dot(world_normal, L)));

	// Smoothly graduate from shoreline warm sand (Y >= -0.05) -> wet coral berm -> submerged turquoise reef below Y=-0.85
	vec3 dry_sand = mix(vec3(0.76, 0.69, 0.52), vec3(0.84, 0.74, 0.54), drought_factor * 0.45);
	dry_sand = mix(dry_sand, vec3(0.56, 0.52, 0.40), rain_factor * 0.40);
	vec3 wet_sand = vec3(0.42, 0.41, 0.32);
	vec3 shallow_reef = mix(vec3(0.11, 0.48, 0.52), vec3(0.13, 0.34, 0.41), rain_factor * 0.45);

	float h = world_position.y;
	vec3 col = mix(wet_sand, dry_sand, smoothstep(-0.42, -0.04, h));
	col = mix(shallow_reef, col, smoothstep(-1.15, -0.40, h));

	vec3 lit = mix(ambient_color * 0.72, sun_color * 1.02, diff) * mix(1.0, 0.30, night_factor);
	col *= lit * cloud_shade(world_position.xz, TIME, rain_factor, drought_factor);
	col = apply_diorama_fog(col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
	ALBEDO = col;
	ROUGHNESS = mix(0.90, 0.45, smoothstep(-0.15, -0.95, h));
}
