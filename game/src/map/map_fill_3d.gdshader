shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
// 3D Strategy Diorama Map Fill: reads region index from UV.x.

uniform sampler2D region_colors : filter_nearest, repeat_disable;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.25;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	vec4 c = texelFetch(region_colors, ivec2(int(UV.x + 0.5), 0), 0);
	if (c.a < 0.01) {
		c = vec4(0.28, 0.62, 0.40, 1.0);
	} else if (c.a < 0.75) {
		float stripe = step(mod(FRAGCOORD.x + FRAGCOORD.y, 7.0), 1.2);
		c.rgb = mix(c.rgb, c.rgb * 0.62, stripe);
	}
	
	ALBEDO = c.rgb;
	ROUGHNESS = roughness_amount;
	SPECULAR = specular_amount;
	EMISSION = c.rgb * 0.12;
}
