shader_type spatial;
render_mode cull_disabled, unshaded;
#include "res://src/map/diorama_common.gdshaderinc"
uniform sampler2D palette : source_color, filter_linear;
uniform bool use_palette = false;
uniform bool warm_roofs = false;
uniform vec4 tint : source_color = vec4(1.0);
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
	vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world.y += region_lift(INSTANCE_CUSTOM.r, selected_region, selected_lift, hovered_region, hovered_lift);
	world_position = world.xyz;
	variation = INSTANCE_CUSTOM.b;
	VERTEX = (inverse(MODEL_MATRIX) * world).xyz;
}

void fragment() {
	vec3 color = tint.rgb;
	if (use_palette) {
		color *= texture(palette, UV).rgb;
	}
	vec3 normal_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 L = normalize(sun_dir);
	vec3 V = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 H = normalize(L + V);
	float sun_diff = max(0.0, dot(normal_world, L));
	vec3 lit = mix(ambient_color * 0.72, sun_color * 1.05, sun_diff);
	lit *= mix(1.0, 0.30, night_factor);

	float window = (1.0 - step(0.27, max(color.r, color.g))) * step(color.r + 0.015, color.b)
		* (1.0 - smoothstep(0.25, 0.65, abs(normal_world.y)));
	float glass_glint = pow(max(0.0, dot(normal_world, H)), 34.0) * window * mix(0.55, 0.15, night_factor);
	float roof = smoothstep(0.4, 0.8, normal_world.y);
	if (warm_roofs) {
		float painted_roof = step(color.r * 1.1, color.g) * step(color.b * 1.05, color.g);
		vec3 roof_color = variation < 0.45 ? vec3(0.58, 0.25, 0.13)
			: variation < 0.75 ? vec3(0.24, 0.34, 0.38) : vec3(0.42, 0.38, 0.24);
		color = mix(color, roof_color, painted_roof * 0.9);
	}
	color *= mix(1.0, mix(0.88, 1.14, variation), roof);

	// Subtle warm window reflection by day; luminous glowing skyscrapers/houses at night
	vec3 day_win = vec3(0.84, 0.70, 0.42) * mix(0.14, 0.38, variation);
	vec3 lit_color = (mix(color, day_win, window * 0.38) * lit + sun_color * glass_glint);
	lit_color *= cloud_shade(world_position.xz, TIME * motion, rain_factor, drought_factor);

	if (night_factor > 0.02) {
		float night_win_on = step(0.18, fract(variation * 3.7 + world_position.y * 0.4));
		vec3 warm_lamp = mix(vec3(1.0, 0.72, 0.28), vec3(0.86, 0.94, 1.0), step(0.75, variation));
		lit_color += warm_lamp * window * night_win_on * night_factor * 1.25;
		// Subtle warm porch/street bounce on house walls at night
		if (warm_roofs) {
			lit_color += vec3(0.95, 0.62, 0.24) * (1.0 - roof) * 0.16 * night_factor;
		}
	}

	if (rain_factor > 0.05) {
		float wet_roof = pow(max(0.0, dot(normal_world, H)), 24.0) * roof * rain_factor * 0.28;
		lit_color += sun_color * wet_roof;
	}

	lit_color = apply_diorama_fog(lit_color, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
	ALBEDO = lit_color;
	ROUGHNESS = mix(0.78, 0.38, rain_factor * roof);
}
