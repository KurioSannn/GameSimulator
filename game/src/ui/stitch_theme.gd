class_name StitchTheme
extends RefCounted
## Builds the game's Godot Theme from res://data/ui/stitch_tokens.json (sampled from the Stitch export).
## Stitch has no live link to Godot: the loop is  Stitch export -> update tokens JSON -> restart.
## Theme type variations: ButtonPrimary (yellow CTA), ButtonAccent (purple), PanelHeader (purple bar),
## PanelCard (deep inset card). Plain Button/PanelContainer use the base Stitch panel look.

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


## Chunky "sticker" box: dark outline, thicker bottom edge for depth.
static func box(fill: Color, edge: Color = Color(), depth: int = -1) -> StyleBoxFlat:
	var shape: Dictionary = tokens().get("shape", {})
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(int(shape.get("radius", 6)))
	s.set_content_margin_all(int(shape.get("pad", 10)))
	s.border_color = edge if edge.a > 0.0 else color("outline")
	s.set_border_width_all(int(shape.get("outline_width", 3)))
	s.border_width_bottom = int(shape.get("outline_width", 3)) + (int(shape.get("depth", 5)) if depth < 0 else depth)
	return s


static func build() -> Theme:
	var t := Theme.new()
	var fonts: Dictionary = tokens().get("fonts", {})
	t.default_font_size = int(fonts.get("size_body", 16))
	for key in ["display_path", "body_path"]:
		var p := str(fonts.get(key, ""))
		if p != "" and ResourceLoader.exists(p):
			var font = load(p)
			if font is Font:
				t.default_font = font
				break
	t.set_color("font_color", "Label", color("text"))
	t.set_stylebox("panel", "PanelContainer", box(color("panel")))

	_button(t, "Button", color("panel"), color("text"))
	t.set_type_variation("ButtonPrimary", "Button")
	_button(t, "ButtonPrimary", color("primary"), color("primary_text"))
	t.set_type_variation("ButtonAccent", "Button")
	_button(t, "ButtonAccent", color("accent"), color("text"))

	# Selectable decision card: yellow edge when chosen (toggle_mode buttons).
	t.set_type_variation("ButtonChoice", "Button")
	_button(t, "ButtonChoice", color("panel_deep"), color("text"))
	t.set_stylebox("pressed", "ButtonChoice", box(color("panel"), color("title_gold"), 3))
	t.set_stylebox("hover_pressed", "ButtonChoice", box(color("panel"), color("title_gold"), 3))
	t.set_type_variation("PanelHeader", "PanelContainer")
	t.set_stylebox("panel", "PanelHeader", box(color("accent")))
	t.set_type_variation("PanelCard", "PanelContainer")
	t.set_stylebox("panel", "PanelCard", box(color("panel_deep"), Color(), 0))
	return t


static func _button(t: Theme, type: String, fill: Color, text: Color, edge: Color = Color()) -> void:
	t.set_stylebox("normal", type, box(fill, edge))
	t.set_stylebox("hover", type, box(fill.lightened(0.12), edge))
	t.set_stylebox("pressed", type, box(fill.darkened(0.18), edge, 1))
	t.set_stylebox("disabled", type, box(fill.darkened(0.45), edge))
	t.set_stylebox("focus", type, box(Color(0, 0, 0, 0), color("title_gold"), 0))
	t.set_color("font_color", type, text)
	t.set_color("font_hover_color", type, text)
	t.set_color("font_pressed_color", type, text)
	t.set_color("font_disabled_color", type, text.darkened(0.4))
