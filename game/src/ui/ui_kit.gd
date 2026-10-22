class_name UiKit
extends RefCounted
## Prototype styling helpers. Final visuals (Cleo/Figma) should replace these via a Theme resource.

const BG := Color("14202b")
const PANEL := Color(0.09, 0.13, 0.17, 0.94)
const PANEL_LIGHT := Color(0.14, 0.19, 0.24, 0.96)
const TEXT := Color("e8e4d8")
const MUTED := Color("9fb0ba")
const ACCENT := Color("e3b341")
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
	var t := Theme.new()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	var btn := panel_style(Color("27394a"), 6, 10)
	var hov := panel_style(Color("34506a"), 6, 10)
	var prs := panel_style(Color("1d2b38"), 6, 10)
	var dis := panel_style(Color("1b242d"), 6, 10)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hov)
	t.set_stylebox("pressed", "Button", prs)
	t.set_stylebox("disabled", "Button", dis)
	t.set_stylebox("focus", "Button", panel_style(Color(0, 0, 0, 0), 6, 10))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.55, 0.6))
	return t


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
