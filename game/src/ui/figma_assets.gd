class_name FigmaAssets
extends RefCounted
## Local assets exported from the user's Figma file. No network requests at runtime.

static var _slots: Array = []


static func path(screen: int, slot: String) -> String:
	if _slots.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/figma/slots.json"))
		if parsed is Array:
			_slots = parsed
	for item in _slots:
		if int(item.screen) == screen and str(item.slot) == slot:
			return str(item.path)
	push_error("Aset Figma tidak ditemukan: %d / %s" % [screen, slot])
	return ""


static func picture(screen: int, slot: String, geometry: Vector2) -> TextureRect:
	var r := UiKit.icon(path(screen, slot), geometry)
	r.set_meta("figma_screen", screen)
	r.set_meta("figma_slot", slot)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func texture(screen: int, slot: String) -> Texture2D:
	return load(path(screen, slot)) as Texture2D


static func portrait(screen: int, geometry: Vector2) -> TextureRect:
	var slot := "imgAvatarPresidenNaraAdinata" if screen == 6 else "imgPotretPresidenNara"
	var tex := texture(screen, slot)
	var crop := AtlasTexture.new()
	crop.atlas = tex
	# The image fill crop returned by Figma (not an edited or rasterized replacement).
	var origin := Vector2(0.2899, 0.0811) if screen == 2 else Vector2(0.30, 0.05)
	crop.region = Rect2(origin * tex.get_size(), Vector2(0.22, 0.36) * tex.get_size())
	var r := TextureRect.new()
	r.texture = crop
	r.set_meta("figma_screen", screen)
	r.set_meta("figma_slot", slot)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = geometry
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func badge(base: String, rim: String, symbol: String) -> Control:
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(110, 110)
	for spec in [[base, Vector2(5, 5), Vector2(100, 100)], [rim, Vector2(14, 14), Vector2(82, 82)], [symbol, Vector2(29, 29), Vector2(52, 52)]]:
		var layer := picture(2, spec[0], Vector2.ZERO)
		layer.position = spec[1]
		layer.size = spec[2]
		canvas.add_child(layer)
	return canvas
