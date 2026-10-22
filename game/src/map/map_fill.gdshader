shader_type canvas_item;
// Map fill: every vertex carries its region index in UV.x (set offline by build_map_lods.py, identical
// for all three triangles' vertices), and the colour comes from a 1-pixel-high lookup texture with one
// texel per region. Recolouring the whole map rewrites only that texture (MapView.recolor).
// Texel alpha < 0.75 marks a value whose starting data is UNCALIBRATED: the region gets fine diagonal
// screen-space hatching so simulated-from-neutral values never look like measured statistics.

uniform sampler2D region_colors : filter_nearest, repeat_disable;

void fragment() {
	vec4 c = texelFetch(region_colors, ivec2(int(UV.x + 0.5), 0), 0);
	if (c.a < 0.75) {
		float stripe = step(mod(FRAGCOORD.x + FRAGCOORD.y, 7.0), 1.2);
		c.rgb = mix(c.rgb, c.rgb * 0.62, stripe);
	}
	COLOR = vec4(c.rgb, 1.0);
}
