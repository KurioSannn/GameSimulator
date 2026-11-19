class_name GameSkin
extends RefCounted
## Original Kenney CC0 artwork. Native controls retain their normal input/focus behavior.
const ROOT := "res://assets/ui/kenney_adventure/"
const FRAME_INSET := 36
const FRAME_BORDER := 24

static func texture(name: String) -> Texture2D:
	return load(ROOT + name + ".png") as Texture2D

static func sprite(name: String, geometry: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture(name)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = geometry
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

static func frame(name: String = "panel_brown_corners_a", inset: int = FRAME_INSET, border: int = FRAME_BORDER,
		tint: Color = Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture(name)
	box.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, border)
		box.set_content_margin(side, inset)
	if name == "banner_hanging":
		box.set_content_margin(SIDE_TOP, 32)
		box.set_content_margin(SIDE_BOTTOM, 32)
	return box

static func apply(theme: Theme) -> void:
	for type in ["PanelContainer", "PanelDock", "PanelElevated"]:
		theme.set_stylebox("panel", type, frame())
	theme.set_stylebox("panel", "PanelCard", StitchTheme.soft_box(Color("f6e9cb"), Color(0, 0, 0, 0), 2, 14, 12, 0))
	theme.set_stylebox("panel", "PanelHeader", frame("banner_hanging", 40, 30))
	for type in ["Button", "ButtonGhost", "ButtonNav", "OptionButton", "MenuButton"]:
		_buttons(theme, type, "button_brown", UiKit.TEXT, 10)
	_buttons(theme, "ButtonPrimary", "button_red", Color("fff7e0"), 10)
	_buttons(theme, "ButtonAccent", "button_brown", UiKit.ACCENT, 10)
	theme.set_stylebox("pressed", "ButtonAccent", frame("button_brown", 10, 10, Color("edd698")))
	theme.set_stylebox("normal", "ButtonAccent", frame("button_brown", 10, 10, Color("edd698")))
	_buttons(theme, "ButtonChoice", "panel_brown", UiKit.TEXT, 16)
	# Selection keeps the same paper frame so corner clasps cannot intrude into text.
	theme.set_stylebox("pressed", "ButtonChoice", frame("panel_brown", 16, 16, Color("edd698")))
	theme.set_stylebox("hover_pressed", "ButtonChoice", frame("panel_brown", 16, 16, Color("edd698")))
	for type in ["ButtonMedallion", "ButtonHex"]:
		theme.set_type_variation(type, "Button")
		_buttons(theme, type, "round_brown" if type == "ButtonMedallion" else "hexagon_brown", UiKit.TEXT, 0)
	theme.set_stylebox("panel", "PopupMenu", frame("panel_brown", 24, 16))
	theme.set_stylebox("hover", "PopupMenu", StitchTheme.soft_box(Color("d7bb85"), Color(0, 0, 0, 0), 0, 10, 8, 0))
	theme.set_color("font_hover_color", "PopupMenu", UiKit.TEXT)
	theme.set_stylebox("panel", "TooltipPanel", frame("panel_brown", 24, 16))
	var separator := StyleBoxLine.new()
	separator.color = Color("8d7654", 0.3)
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)
	for type in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", type, StitchTheme.soft_box(Color("cab88e"), Color(0, 0, 0, 0), 3, 3, 3, 0))
		theme.set_stylebox("grabber", type, StitchTheme.soft_box(Color("8b6c48"), Color(0, 0, 0, 0), 3, 3, 3, 0))
		theme.set_stylebox("grabber_highlight", type, StitchTheme.soft_box(Color("614c35"), Color(0, 0, 0, 0), 3, 3, 3, 0))

## Map chrome uses a lighter frame; 16px matches panel_brown's painted wood border cleanly.
static func hud_frame() -> StyleBoxTexture:
	var box := frame("panel_brown", 24, 16)
	box.set_content_margin(SIDE_TOP, 18)
	box.set_content_margin(SIDE_BOTTOM, 18)
	return box

static func _buttons(theme: Theme, type: String, asset: String, text: Color, inset: int) -> void:
	var h_inset := inset + 12 if inset > 0 and asset.begins_with("button_") else inset
	var normal := frame(asset, inset, inset)
	var hover := frame(asset, inset, inset, Color("fff2c7"))
	var pressed := frame(asset, inset, inset, Color("d8c5a0"))
	var disabled := frame("button_brown" if inset > 0 else asset, inset, inset, Color("d3c9b6"))
	for box in [normal, hover, pressed, disabled]:
		box.set_content_margin(SIDE_LEFT, h_inset)
		box.set_content_margin(SIDE_RIGHT, h_inset)
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, hover)
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("hover_pressed", type, pressed)
	theme.set_stylebox("disabled", type, disabled)
	var focus := StitchTheme.soft_box(Color(0, 0, 0, 0), Color("774222"), 3, h_inset, inset, 3)
	theme.set_stylebox("focus", type, focus)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(key, type, text)
	theme.set_color("font_disabled_color", type, Color("61594c"))
