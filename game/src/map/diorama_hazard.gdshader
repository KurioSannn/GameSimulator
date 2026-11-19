shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
#include "res://src/map/diorama_common.gdshaderinc"
uniform int fx_mode = 0; // 0=rain, 1=flood_pool, 2=fire, 3=smoke, 4=macet_traffic, 5=quake_disaster
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
		float drop = fract(t * (1.5 + seed_var * 0.8) + cust_g);
		world.y = mix(220.0, 0.0, drop) + VERTEX.y;
		world.x -= drop * 38.0;
	} else if (fx_mode == 2) {
		float sway = sin(t * 7.5 + phase + VERTEX.y * 0.3) * max(VERTEX.y, 0.0) * 0.14 * motion;
		world.x += sway;
	} else if (fx_mode == 3) {
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
		// Irregular standing murky-turquoise floodwater pool + spreading surface flood ripples
		vec2 p = UV * 2.0 - 1.0;
		float distort = (art_fbm(p * 2.3 + vec2(phase, phase * 0.7)) - 0.5) * 0.30;
		float r = length(p) + distort;
		if (r > 0.92) discard;
		float pool = smoothstep(0.92, 0.42, r) * 0.62;
		float w1 = fract(t * 0.52 + cust_g);
		float w2 = fract(t * 0.52 + cust_g + 0.5);
		float ring1 = smoothstep(0.11, 0.0, abs(r - w1 * 0.84)) * (1.0 - w1);
		float ring2 = smoothstep(0.11, 0.0, abs(r - w2 * 0.84)) * (1.0 - w2);
		float swirl = art_noise(p * 5.5 + vec2(t * 0.45, -t * 0.38)) * 0.16 * smoothstep(0.88, 0.25, r);
		float alpha = clamp((pool + ring1 * 0.55 + ring2 * 0.45 + swirl) * intensity, 0.0, 0.86);
		if (alpha < 0.015) discard;
		vec3 muddy_water = mix(vec3(0.16, 0.44, 0.45), vec3(0.24, 0.64, 0.72), swirl * 3.5);
		vec3 col = mix(muddy_water, vec3(0.84, 0.97, 1.0), clamp((ring1 + ring2) * 0.85, 0.0, 1.0));
		ALBEDO = apply_diorama_fog(col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
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
	} else if (fx_mode == 3) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		if (r > 0.96) discard;
		float puff = art_fbm3(UV * 3.2 + vec2(phase, -t * 0.22));
		float alpha = smoothstep(0.92, 0.18, r) * smoothstep(0.28, 0.82, puff + 0.22) * intensity * 0.42;
		if (alpha < 0.015) discard;
		vec3 col = mix(vec3(0.26, 0.23, 0.22), vec3(0.76, 0.56, 0.38), smoothstep(0.55, 0.9, puff));
		ALBEDO = apply_diorama_fog(col, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
		ALPHA = alpha;
	} else if (fx_mode == 4) {
		// Kota Macet / Urban Gridlock: glowing red-amber stop-and-go traffic arterial queues
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		if (r > 0.96) discard;
		float radial_fade = smoothstep(0.95, 0.35, r);
		float lane_x = smoothstep(0.16, 0.03, abs(p.y));
		float lane_z = smoothstep(0.16, 0.03, abs(p.x));
		float crawl_x = pow(0.5 + 0.5 * sin(p.x * 22.0 - t * 2.2 + phase), 3.0);
		float crawl_z = pow(0.5 + 0.5 * sin(p.y * 22.0 + t * 1.9 + phase), 3.0);
		float jam_core = smoothstep(0.55, 0.0, r) * (0.28 + 0.14 * sin(t * 3.2 + phase));
		float beads = max(lane_x * (0.35 + crawl_x * 0.75), lane_z * (0.35 + crawl_z * 0.75));
		float alpha = clamp((max(beads, jam_core) * radial_fade) * intensity * 0.85, 0.0, 0.90);
		if (alpha < 0.02) discard;
		vec3 col = mix(vec3(0.96, 0.22, 0.10), vec3(1.0, 0.76, 0.18), clamp(crawl_x * lane_x + crawl_z * lane_z, 0.0, 1.0) * 0.72);
		ALBEDO = apply_diorama_fog(col * 1.25, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
		ALPHA = alpha;
	} else {
		// Gempa / Bencana Seismic Shockwave: pulsing tectonic waves + warning fissure epicenter
		vec2 p = UV * 2.0 - 1.0;
		float jagged = (art_noise(p * 6.5 + phase) - 0.5) * 0.10;
		float r = length(p) + jagged;
		if (r > 0.98) discard;
		float w1 = fract(t * 0.68 + cust_g);
		float w2 = fract(t * 0.68 + cust_g + 0.5);
		float shock1 = smoothstep(0.11, 0.0, abs(r - w1 * 0.92)) * (1.0 - w1);
		float shock2 = smoothstep(0.11, 0.0, abs(r - w2 * 0.92)) * (1.0 - w2);
		float epi = smoothstep(0.24, 0.0, r) * (0.65 + 0.35 * sin(t * 4.5 + phase));
		float alpha = clamp((shock1 + shock2 + epi * 0.85) * intensity * 0.88, 0.0, 0.92);
		if (alpha < 0.02) discard;
		vec3 col = mix(vec3(0.95, 0.28, 0.08), vec3(1.0, 0.84, 0.26), smoothstep(0.35, 0.95, epi + shock1 * 0.6));
		ALBEDO = apply_diorama_fog(col * 1.30, world_position, CAMERA_POSITION_WORLD, fog_color, fog_density);
		ALPHA = alpha;
	}
}
