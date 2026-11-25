class_name PresidentPortrait
extends Control
## One grounded illustration, resized from its visible alpha bounds rather than a VBox gap.
## Original Figma PNG: 500x790; alpha>=32 bounds (14,34)-(470,784).
const VISIBLE_BOUNDS := Rect2(14, 34, 456, 750)
var artwork: TextureRect
var art_rect := Rect2()
var contact_y := 0.0
var shadow_rect := Rect2()

func _init() -> void:
	custom_minimum_size = Vector2(200, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork = FigmaAssets.picture(2, "imgNaraAdinataKarakterPemain", Vector2.ZERO)
	var cropped := AtlasTexture.new()
	cropped.atlas = artwork.texture
	cropped.region = VISIBLE_BOUNDS
	artwork.texture = cropped
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(artwork)
	resized.connect(_layout_art)

func _layout_art() -> void:
	var available := Vector2(maxf(1, size.x - 48), maxf(1, size.y - 36))
	var scale := minf(available.x / VISIBLE_BOUNDS.size.x, available.y / VISIBLE_BOUNDS.size.y)
	var extent := VISIBLE_BOUNDS.size * scale
	contact_y = size.y - 14
	art_rect = Rect2(Vector2((size.x - extent.x) * 0.5, contact_y - extent.y), extent)
	artwork.position = art_rect.position
	artwork.size = art_rect.size
	var shadow_size := Vector2(extent.x * 0.55, maxf(8, extent.y * 0.022))
	var center := Vector2(art_rect.position.x + extent.x * 0.43, contact_y - 3)
	shadow_rect = Rect2(center - shadow_size * 0.5, shadow_size)
	queue_redraw()

func _draw() -> void:
	# Soft contact shadow is drawn behind the original illustration; no new raster asset.
	for layer in range(5, 0, -1):
		var factor := float(layer) / 5.0
		var points := PackedVector2Array()
		for index in 48:
			var angle := TAU * float(index) / 48.0
			points.append(shadow_rect.get_center() + Vector2(cos(angle), sin(angle)) * shadow_rect.size * 0.5 * factor)
		draw_colored_polygon(points, Color("5a452b", 0.045))
