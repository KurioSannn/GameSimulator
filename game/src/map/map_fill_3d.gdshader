shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
// 3D Tabletop Map Fill: reads region index from UV.x (identical to 2D MapView).

uniform sampler2D region_colors : filter_nearest, repeat_disable;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.15;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	vec4 c = texelFetch(region_colors, ivec2(int(UV.x + 0.5), 0), 0);
	if (c.a < 0.01) {
		c = vec4(0.32, 0.58, 0.42, 1.0);
	} else if (c.a < 0.75) {
		float stripe = step(mod(FRAGCOORD.x + FRAGCOORD.y, 7.0), 1.2);
		c.rgb = mix(c.rgb, c.rgb * 0.62, stripe);
	}
	ALBEDO = c.rgb;
	ROUGHNESS = roughness_amount;
	SPECULAR = specular_amount;
	EMISSION = c.rgb * 0.25;
}
