shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
#include "res://src/map/diorama_common.gdshaderinc"
uniform int fx_mode = 0; // 0 = rain_streak, 1 = flood_ripple, 2 = fire_flame, 3 = smoke_plume
uniform float motion = 1.0;
uniform float intensity = 1.0;
uniform vec3 fog_color = vec3(0.42, 0.66, 0.80);
uniform float fog_density = 0.00024;
varying float phase;
varying float seed_var;
varying float cust_g;
varying vec3 world_position;

void vertex() {
	cust_g = INSTANCE_CUSTOM.g;
	phase = cust_g * 6.283;
	seed_var = INSTANCE_CUSTOM.b;
	vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
	float t = TIME * motion;
	if (fx_mode == 0) {
		// Falling diagonal tropical rain streaks looping cleanly vertically
		float drop = fract(t * (1.5 + seed_var * 0.8) + cust_g);
		world.y = mix(220.0, 0.0, drop) + VERTEX.y;
		world.x -= drop * 38.0;
	} else if (fx_mode == 2) {
		// Flickering wildfire flames swaying gently
		float sway = sin(t * 7.5 + phase + VERTEX.y * 0.3) * max(VERTEX.y, 0.0) * 0.14 * motion;
		world.x += sway;
	} else if (fx_mode == 3) {
		// Rising smoke column billowing slightly eastward with drift
		float rise = fract(t * (0.14 + seed_var * 0.08) + cust_g);
		world.y += rise * 85.0;
		world.x += rise * 48.0 + sin(t * 1.4 + phase) * 5.0 * motion;
		world.z += cos(t * 1.1 + phase) * 4.0 * motion;
	}
	world_position = world.xyz;
	VERTEX = (inverse(MODEL_MATRIX) * world).xyz;
}

void fragment() {
	if (intensity < 0.02) {
		discard;
	}
	float t = TIME * motion;
	if (fx_mode == 0) {
		vec2 p = UV * 2.0 - 1.0;
		float streak = smoothstep(0.65, 0.0, abs(p.x)) * smoothstep(1.0, 0.1, abs(p.y));
		float alpha = streak * intensity * 0.32;
		if (alpha < 0.015) discard;
		ALBEDO = vec3(0.76, 0.88, 0.96);
		ALPHA = alpha;
	} else if (fx_mode == 1) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		if (r > 0.98) discard;
		float wave = fract(t * 0.55 + cust_g);
		float ring = smoothstep(0.14, 0.0, abs(r - wave * 0.88)) * (1.0 - wave);
		float inner = smoothstep(0.45, 0.0, r) * 0.25;
		float alpha = (ring + inner) * intensity * 0.72;
		if (alpha < 0.015) discard;
		ALBEDO = mix(vec3(0.18, 0.72, 0.96), vec3(0.84, 0.97, 1.0), ring);
		ALPHA = alpha;
	} else if (fx_mode == 2) {
		vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
		float n = art_fbm(vec2(UV.x * 4.0 + phase, UV.y * 3.5 - t * 3.2));
		float taper = smoothstep(0.95, 0.08, p.y) * smoothstep(1.0 - p.y * 0.7, 0.1, abs(p.x));
		float flame = taper * smoothstep(0.24, 0.76, n + (1.0 - p.y) * 0.35);
		if (flame < 0.04) discard;
		vec3 fire_col = mix(vec3(0.92, 0.22, 0.04), vec3(1.0, 0.86, 0.22), smoothstep(0.4, 0.92, flame));
		ALBEDO = fire_col * 1.45;
		ALPHA = clamp(flame * intensity * 1.15, 0.0, 0.95);
	} else {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		if (r > 0.96) discard;
		float puff = art_fbm3(UV * 3.2 + vec2(phase, -t * 0.22));
		float alpha = smoothstep(0.92, 0.18, r) * smoothstep(0.28, 0.82, puff + 0.22) * intensity * 0.42;
		if (alpha < 0.015) discard;
		vec3 col = mix(vec3(0.26, 0.23, 0.22), vec3(0.76, 0.56, 0.38), smoothstep(0.55, 0.9, puff));
		ALBEDO = apply_diorama_fog(col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
		ALPHA = alpha;
	}
}
