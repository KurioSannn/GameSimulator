class_name UiKit
extends RefCounted
## Prototype styling helpers. Final visuals (Cleo/Figma) should replace these via a Theme resource.

# Palette mirrors data/ui/stitch_tokens.json (checked by tests/test_ui_theme.gd).
const BG := Color("133b7a")
const PANEL := Color("283f83")
const PANEL_LIGHT := Color("283f83")
const TEXT := Color("ffffff")
const MUTED := Color("b9c4e8")
const ACCENT := Color("ffdc45")
const REAL := Color("6fbf8e")
const SIM := Color("7fa8d9")
const FICTION := Color("c69bd6")
const WARN := Color("e08a5a")


static func panel_style(color: Color = PANEL, radius: int = 8, pad: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.border_color = Color(1, 1, 1, 0.06)
	s.set_border_width_all(1)
	return s


static func make_theme() -> Theme:
	return StitchTheme.build()


static func label(text: String, size: int = 16, color: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Small pill tag used to label fact classes (NYATA / SIMULASI / FIKSI / BELUM TERKALIBRASI).
static func tag(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := panel_style(Color(color, 0.18), 4, 4)
	s.border_color = Color(color, 0.7)
	p.add_theme_stylebox_override("panel", s)
	p.add_child(label(text, 11, color))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p


static func vbox(sep: int = 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func hbox(sep: int = 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Outlined, heavy "sticker" title label (Stitch headings). Uses a bold system font until the team supplies one.
static func title(text: String, size: int = 20, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Arial Rounded MT Bold", "Arial Black", "Impact", "Helvetica Neue"])
	f.font_weight = 800
	l.add_theme_font_override("font", f)
	l.add_theme_constant_override("outline_size", maxi(2, size / 6))
	l.add_theme_color_override("font_outline_color", StitchTheme.color("outline"))
	return l


static func icon(path: String, min_size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	if ResourceLoader.exists(path):
		r.texture = load(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = min_size
	return r
