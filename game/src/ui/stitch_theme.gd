class_name StitchTheme
extends RefCounted
## Builds the game's Godot Theme from res://data/ui/stitch_tokens.json.
## Three-tier visual hierarchy:
##   1. Outer windows & interactive buttons: crisp tactile outline + subtle bottom lip.
##   2. Floating HUD docks: dark translucent glass with subtle 1px edge.
##   3. Inner cards & metric tiles (PanelCard): calm low-border inset surfaces without visual noise.

const TOKENS_PATH := "res://data/ui/stitch_tokens.json"

static var _tokens: Dictionary = {}


static func tokens() -> Dictionary:
	if _tokens.is_empty():
		var f := FileAccess.open(TOKENS_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_tokens = parsed
		if _tokens.is_empty():
			push_error("StitchTheme: cannot read " + TOKENS_PATH)
	return _tokens


static func color(key: String) -> Color:
	return Color(str(tokens().get("colors", {}).get(key, "#ff00ff")))


## Crisp tactile box for outer frames and interactive buttons.
static func box(fill: Color, edge: Color = Color(), depth: int = -1, radius_override: int = -1, pad_x: int = -1, pad_y: int = -1) -> StyleBoxFlat:
	var shape: Dictionary = tokens().get("shape", {})
	var radius := int(shape.get("radius", 10)) if radius_override < 0 else radius_override
	var pad := int(shape.get("pad", 14))
	var outline := int(shape.get("outline_width", 2))
	var lip := int(shape.get("depth", 4)) if depth < 0 else depth
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad if pad_x < 0 else pad_x
	s.content_margin_right = pad if pad_x < 0 else pad_x
	s.content_margin_top = pad if pad_y < 0 else pad_y
	s.content_margin_bottom = pad if pad_y < 0 else pad_y
	s.border_color = edge if edge.a > 0.0 else color("outline")
	s.set_border_width_all(outline)
	s.border_width_bottom = outline + lip
	return s


## Calm, low-noise inner card surface (1px subtle hairline, zero bottom lip).
static func soft_box(fill: Color, edge: Color = Color(1, 1, 1, 0.11), radius: int = 8, pad_x: int = 12, pad_y: int = 10, border: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	s.border_color = edge
	s.set_border_width_all(border)
	return s


## Translucent floating HUD dock style.
static func glass_box(radius: int = 12, pad_x: int = 14, pad_y: int = 10) -> StyleBoxFlat:
	return soft_box(color("panel_glass"), Color(1, 1, 1, 0.14), radius, pad_x, pad_y, 1)


static func build() -> Theme:
	var t := Theme.new()
	var fonts: Dictionary = tokens().get("fonts", {})
	var body_font: Font = load(str(fonts.get("body_path", "res://assets/fonts/Inter.ttf")))
	var display_font: Font = load(str(fonts.get("display_path", "res://assets/fonts/LilitaOne-Regular.ttf")))
	t.default_font_size = UiKit.font_size(int(fonts.get("size_body", 16)))
	if body_font != null:
		t.default_font = body_font

	# Text & basic widgets
	for cls in ["Label", "RichTextLabel", "CheckButton", "CheckBox", "OptionButton", "LineEdit"]:
		t.set_color("font_color", cls, color("text"))
	t.set_color("font_placeholder_color", "LineEdit", color("text_muted"))
	t.set_stylebox("normal", "LineEdit", soft_box(color("panel_soft"), Color(1, 1, 1, 0.16), 8, 12, 8))
	t.set_stylebox("focus", "LineEdit", soft_box(color("panel_deep"), color("title_gold"), 8, 12, 8, 2))
	t.set_stylebox("read_only", "LineEdit", soft_box(color("panel_soft"), Color(1, 1, 1, 0.06), 8, 12, 8))

	# ProgressBar: clean pill track without heavy border
	var pb_bg := soft_box(Color("0b1736"), Color(1, 1, 1, 0.10), 99, 0, 0, 1)
	var pb_fill := soft_box(color("primary"), Color(1, 1, 1, 0.25), 99, 0, 0, 0)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	# Separators
	var sep := StyleBoxLine.new()
	sep.color = Color(1, 1, 1, 0.10)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	var vsep := StyleBoxLine.new()
	vsep.color = Color(1, 1, 1, 0.10)
	vsep.thickness = 1
	vsep.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep)

	# ScrollBars: thin, unobtrusive rounded grabbers
	var sb_track := soft_box(Color(0, 0, 0, 0.18), Color(0, 0, 0, 0), 99, 3, 3, 0)
	var sb_grab := soft_box(Color(1, 1, 1, 0.22), Color(0, 0, 0, 0), 99, 3, 3, 0)
	var sb_grab_hl := soft_box(Color(1, 1, 1, 0.42), Color(0, 0, 0, 0), 99, 3, 3, 0)
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, sb_track)
		t.set_stylebox("grabber", sb, sb_grab)
		t.set_stylebox("grabber_highlight", sb, sb_grab_hl)
		t.set_stylebox("grabber_pressed", sb, sb_grab_hl)

	# Sliders
	var sl_bg := soft_box(Color("0b1736"), Color(1, 1, 1, 0.14), 99, 0, 4, 1)
	var sl_fill := soft_box(color("accent"), Color(0, 0, 0, 0), 99, 0, 4, 0)
	t.set_stylebox("slider", "HSlider", sl_bg)
	t.set_stylebox("grabber_area", "HSlider", sl_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", soft_box(color("title_gold"), Color(0, 0, 0, 0), 99, 0, 4, 0))

	# Panels
	t.set_stylebox("panel", "PanelContainer", box(color("surface"), color("outline"), 4, 12, 18, 16))
	t.set_type_variation("PanelCard", "PanelContainer")
	t.set_stylebox("panel", "PanelCard", soft_box(color("panel_soft"), Color(1, 1, 1, 0.11), 10, 14, 12, 1))
	t.set_type_variation("PanelElevated", "PanelContainer")
	t.set_stylebox("panel", "PanelElevated", soft_box(color("panel"), Color(1, 1, 1, 0.16), 10, 14, 12, 1))
	t.set_type_variation("PanelDock", "PanelContainer")
	t.set_stylebox("panel", "PanelDock", glass_box(12, 14, 10))
	t.set_type_variation("PanelHeader", "PanelContainer")
	var hdr_box := soft_box(Color("223978"), Color(1, 1, 1, 0.14), 10, 16, 10, 1)
	hdr_box.border_width_left = 4
	hdr_box.border_color = color("title_gold")
	t.set_stylebox("panel", "PanelHeader", hdr_box)

	# Buttons
	var btn_font_size := UiKit.font_size(17)
	_button(t, "Button", color("panel"), color("text"), Color(), 3, display_font, btn_font_size, 16, 9)
	t.set_type_variation("ButtonPrimary", "Button")
	_button(t, "ButtonPrimary", color("primary"), color("primary_text"), color("outline"), 4, display_font, UiKit.font_size(18), 18, 10)
	t.set_type_variation("ButtonAccent", "Button")
	_button(t, "ButtonAccent", color("panel_deep"), color("title_gold"), color("title_gold"), 1, display_font, btn_font_size, 16, 9)
	t.set_type_variation("ButtonGhost", "Button")
	_ghost_button(t, "ButtonGhost", body_font, UiKit.font_size(15))
	t.set_type_variation("ButtonNav", "Button")
	_ghost_button(t, "ButtonNav", display_font, UiKit.font_size(15))

	# OptionButton & MenuButton & PopupMenu
	_button(t, "OptionButton", color("panel_soft"), color("title_gold"), Color(1, 1, 1, 0.18), 1, body_font, UiKit.font_size(15), 12, 8)
	_button(t, "MenuButton", color("panel_soft"), color("text"), Color(1, 1, 1, 0.18), 1, body_font, UiKit.font_size(15), 12, 8)
	t.set_stylebox("panel", "PopupMenu", soft_box(color("panel_deep"), color("border_subtle"), 10, 6, 6, 1))
	t.set_stylebox("hover", "PopupMenu", soft_box(color("panel"), Color(1, 1, 1, 0.12), 6, 10, 6, 0))
	t.set_color("font_color", "PopupMenu", color("text"))
	t.set_color("font_hover_color", "PopupMenu", color("title_gold"))
	t.set_color("font_separator_color", "PopupMenu", color("text_muted"))
	t.set_font_size("font_size", "PopupMenu", UiKit.font_size(14))

	# CheckButton
	t.set_color("font_color", "CheckButton", color("text"))
	t.set_color("font_hover_color", "CheckButton", color("title_gold"))
	t.set_color("font_pressed_color", "CheckButton", color("text"))
	t.set_font_size("font_size", "CheckButton", UiKit.font_size(14))
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())

	# Selectable decision card (clean 2px subtle border normal, vivid gold highlight when selected)
	t.set_type_variation("ButtonChoice", "Button")
	var bc_normal := soft_box(Color("132657"), Color(1, 1, 1, 0.16), 12, 16, 14, 2)
	var bc_hover := soft_box(Color("1b3575"), color("border_subtle"), 12, 16, 14, 2)
	var bc_pressed := soft_box(Color("1e3c85"), color("title_gold"), 12, 16, 14, 3)
	var bc_focus := soft_box(Color(0, 0, 0, 0), Color.WHITE, 12, 16, 14, 3)
	t.set_stylebox("normal", "ButtonChoice", bc_normal)
	t.set_stylebox("hover", "ButtonChoice", bc_hover)
	t.set_stylebox("pressed", "ButtonChoice", bc_pressed)
	t.set_stylebox("hover_pressed", "ButtonChoice", bc_pressed)
	t.set_stylebox("disabled", "ButtonChoice", soft_box(color("panel_deep"), Color(1, 1, 1, 0.06), 10, 16, 14, 1))
	t.set_stylebox("focus", "ButtonChoice", bc_focus)
	if body_font != null:
		t.set_font("font", "ButtonChoice", body_font)
	t.set_font_size("font_size", "ButtonChoice", UiKit.font_size(15))
	for ckey in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(ckey, "ButtonChoice", color("text"))

	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", soft_box(Color("0b1633", 0.96), color("border_subtle"), 8, 12, 8, 1))
	t.set_color("font_color", "TooltipLabel", color("text"))
	t.set_font_size("font_size", "TooltipLabel", UiKit.font_size(13))

	return t


static func _button(t: Theme, type: String, fill: Color, text: Color, edge: Color, depth: int,
		font: Font, font_size: int, pad_x: int, pad_y: int) -> void:
	t.set_stylebox("normal", type, box(fill, edge, depth, 9, pad_x, pad_y))
	t.set_stylebox("hover", type, box(fill.lightened(0.10), edge, depth, 9, pad_x, pad_y))
	t.set_stylebox("pressed", type, box(fill.darkened(0.15), edge, maxi(0, depth - 2), 9, pad_x, pad_y))
	t.set_stylebox("disabled", type, soft_box(fill.darkened(0.45), Color(1, 1, 1, 0.08), 9, pad_x, pad_y, 1))
	var focus := soft_box(Color(0, 0, 0, 0), Color.WHITE, 9, pad_x, pad_y, 3)
	t.set_stylebox("focus", type, focus)
	if font != null:
		t.set_font("font", type, font)
	t.set_font_size("font_size", type, font_size)
	for ckey in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(ckey, type, text)
	t.set_color("font_disabled_color", type, text.darkened(0.42))


static func _ghost_button(t: Theme, type: String, font: Font, font_size: int) -> void:
	t.set_stylebox("normal", type, soft_box(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.14), 8, 12, 8, 1))
	t.set_stylebox("hover", type, soft_box(Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.28), 8, 12, 8, 1))
	t.set_stylebox("pressed", type, soft_box(Color(1, 1, 1, 0.22), color("title_gold"), 8, 12, 8, 2))
	t.set_stylebox("disabled", type, soft_box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06), 8, 12, 8, 1))
	t.set_stylebox("focus", type, soft_box(Color(0, 0, 0, 0), Color.WHITE, 8, 12, 8, 2))
	if font != null:
		t.set_font("font", type, font)
	t.set_font_size("font_size", type, font_size)
	for ckey in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(ckey, type, color("text"))
	t.set_color("font_disabled_color", type, color("text_muted").darkened(0.35))
