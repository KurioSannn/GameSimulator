class_name UiKit
extends RefCounted
## Shared native controls and clean layout helpers for the NUSANTARA desktop interface.

# Palette constants stay synced with data/ui/stitch_tokens.json (verified by tests/test_ui_theme.gd).
const BG := Color("a79473")
const PANEL := Color("dfcfaa")
const PANEL_LIGHT := Color("f1e0bb")
const PANEL_SOFT := Color("f6e9cb")
const TEXT := Color("302e28")
const MUTED := Color("6b604c")
const ACCENT := Color("78451f")
const REAL := Color("367453")
const SIM := Color("3f6878")
const INFO := Color("3f6878")
const FICTION := Color("76526b")
const WARN := Color("a64c2b")
const SUCCESS := Color("367453")
const DANGER := Color("aa3c2c")


static func panel_style(color: Color = PANEL, radius: int = 10, pad: int = 14) -> StyleBoxFlat:
	return StitchTheme.soft_box(color, Color(1, 1, 1, 0.12), radius, pad, pad, 1)


static func make_theme() -> Theme:
	return StitchTheme.build()


## 1440x810 desktop canvas: minimum text is about 19.6 output pixels at 1280x720.
static func font_size(size: int) -> int:
	return roundi(maxi(22, size) * float(UiPreferences.values.text_scale))


static func label(text: String, size: int = 15, color: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.set_meta("base_font_size", size)
	l.add_theme_font_override("font", load(str(StitchTheme.tokens().fonts.body_path)))
	l.add_theme_font_size_override("font_size", font_size(size))
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Clean readable pill badge (fact class, status, warnings).
static func tag(text: String, color: Color, size: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StitchTheme.soft_box(Color(color, 0.16), Color(color, 0.45), 6, 9, 4, 1)
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, size, color.lightened(0.22))
	l.add_theme_font_override("font", load(str(StitchTheme.tokens().fonts.body_path)))
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if text.length() > 64:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


## Bree Serif for major titles; Alegreya Sans Bold for small headings and option names.
static func title(text: String, size: int = 20, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	var font_path: String = StitchTheme.tokens().fonts.display_path if size >= 24 else StitchTheme.tokens().fonts.strong_path
	l.add_theme_font_override("font", load(font_path))
	l.add_theme_constant_override("outline_size", 0)
	return l


## Bold numeric readouts share the main family; hierarchy comes from size and weight.
static func number(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var value := label(text, size, color)
	value.add_theme_font_override("font", load(str(StitchTheme.tokens().fonts.number_path)))
	return value


static func subheader(text: String, color: Color = MUTED, size: int = 12) -> Label:
	var l := label(text.to_upper(), size, color)
	l.add_theme_font_override("font", load(str(StitchTheme.tokens().fonts.strong_path)))
	l.add_theme_constant_override("outline_size", 0)
	return l


static func icon(path: String, min_size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	if ResourceLoader.exists(path):
		r.texture = load(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = min_size
	return r


static func button(text: String, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "ButtonPrimary" if primary else "Button"
	b.custom_minimum_size.y = 44
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	return b


static func ghost_button(text: String, action: Callable, tooltip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "ButtonGhost"
	b.custom_minimum_size.y = 38
	b.tooltip_text = tooltip
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	return b


static func heading(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "PanelHeader"
	var t := title(text, 22, Color("fff4d2"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(t)
	return p


## Clean typographic section divider with header + optional right subheader caption.
static func section_bar(title_text: String, subtitle_text: String = "", accent_color: Color = ACCENT) -> VBoxContainer:
	var v := vbox(5)
	var row := hbox(8)
	var t := title(title_text, 16, accent_color)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	if subtitle_text != "":
		var sub := label(subtitle_text, 12, MUTED)
		row.add_child(sub)
	v.add_child(row)
	v.add_child(HSeparator.new())
	return v


## Crisp two-column key-value row with aligned tabular value on the right.
static func kv_row(key_text: String, val_text: String, val_color: Color = TEXT, size: int = 14) -> HBoxContainer:
	var r := hbox(12)
	var k := label(key_text, size, MUTED, true)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(k)
	var v := label(val_text, size, val_color)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_stretch_ratio = 1.3
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(v)
	return r


## Reusable modal top bar: eyebrow + title + optional urgent badge + close button.
static func modal_header(eyebrow: String, title_text: String, on_close: Callable,
		badge_text: String = "", badge_color: Color = DANGER, close_text: String = "✕", close_tip: String = "Tutup (Esc)") -> HBoxContainer:
	var row := hbox(12)
	var bar := PanelContainer.new()
	bar.theme_type_variation = "PanelHeader"
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := vbox(2)
	if eyebrow != "":
		col.add_child(subheader(eyebrow, Color("fff4d2"), 11))
	var t := title(title_text, 32, Color("fff4d2"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	bar.add_child(col)
	row.add_child(bar)
	if badge_text != "":
		var b := tag(badge_text, badge_color, 13)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	var close := Button.new()
	close.text = close_text
	close.theme_type_variation = "ButtonGhost"
	close.custom_minimum_size = Vector2(44, 44)
	close.tooltip_text = close_tip
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(on_close)
	row.add_child(close)
	return row


static func spacer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Composite button decoration must not intercept the native button's mouse input.
static func ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			ignore_mouse(child)


## Gentle open animation respecting reduce_motion accessibility preference.
static func animate_open(ctrl: Control) -> void:
	if ctrl == null or not ctrl.is_inside_tree():
		return
	if bool(UiPreferences.values.reduce_motion):
		ctrl.modulate.a = 1.0
		return
	ctrl.modulate.a = 0.0
	var tw := ctrl.create_tween()
	tw.tween_property(ctrl, "modulate:a", 1.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func rescale(node: Node) -> void:
	if node is Control and node.has_meta("hud_font_size"):
		hud_type(node, int(node.get_meta("hud_font_size")))
	elif node is Control and node.has_meta("base_font_size"):
		node.add_theme_font_size_override("font_size", font_size(int(node.get_meta("base_font_size"))))
	for child in node.get_children():
		rescale(child)


## Compact map readouts have their own role, retaining the user's text-scale setting.
static func hud_type(control: Control, size: int = 20) -> void:
	control.set_meta("hud_font_size", size)
	control.add_theme_font_size_override("font_size", roundi(maxi(18, size) * float(UiPreferences.values.text_scale)))


static func trap_focus(surface: Control) -> void:
	var focusable: Array[Control] = []
	for control in surface.find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE and not (control is BaseButton and control.disabled):
			focusable.append(control)
	for i in focusable.size():
		focusable[i].focus_next = focusable[i].get_path_to(focusable[(i + 1) % focusable.size()])
		focusable[i].focus_previous = focusable[i].get_path_to(focusable[(i - 1 + focusable.size()) % focusable.size()])
	if not focusable.is_empty():
		focusable[0].grab_focus()
