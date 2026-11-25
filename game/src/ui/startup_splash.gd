class_name StartupSplash
extends ColorRect
## Startup onboarding sequence: dark engine/studio logos followed by a clean white AAA title splash.

signal finished

var _stage: CenterContainer
var _slide: VBoxContainer
var _logo: TextureRect
var _caption: Label
var _tween: Tween
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.0, 0.0, 0.0, 1.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_stage = CenterContainer.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_slide = UiKit.vbox(14)
	_slide.alignment = BoxContainer.ALIGNMENT_CENTER
	_slide.modulate.a = 0.0
	_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_slide)

	_logo = TextureRect.new()
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide.add_child(_logo)

	_caption = UiKit.subheader("", Color(0.82, 0.85, 0.90, 0.85), 14)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide.add_child(_caption)

	_play.call_deferred()


func _play() -> void:
	var fast := bool(UiPreferences.values.get("reduce_motion", false))
	var fade_in := 0.12 if fast else 0.40
	var hold_godot := 0.50 if fast else 0.95
	var hold_studio := 0.55 if fast else 1.15
	var hold_title := 0.65 if fast else 1.45
	var fade_out := 0.12 if fast else 0.35

	var godot_tex := load("res://assets/ui/godot_logo.svg") as Texture2D
	var studio_tex := load("res://assets/ui/333studio.png") as Texture2D
	var title_tex := load("res://assets/ui/nusantara_logo.png") as Texture2D

	_tween = create_tween()
	if godot_tex != null:
		_show_slide(godot_tex, Vector2(180, 180), "")
		_tween.tween_property(_slide, "modulate:a", 1.0, fade_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(hold_godot)
		_tween.tween_property(_slide, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if studio_tex != null:
		_tween.tween_callback(func(): _show_slide(studio_tex, Vector2(520, 260), ""))
		_tween.tween_property(_slide, "modulate:a", 1.0, fade_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(hold_studio)
		_tween.tween_property(_slide, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if title_tex != null:
		_tween.tween_property(self, "color", Color(1.0, 1.0, 1.0, 1.0), fade_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_callback(func(): _show_slide(title_tex, Vector2(540, 405), ""))
		_tween.tween_property(_slide, "modulate:a", 1.0, fade_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(hold_title)
		_tween.tween_property(_slide, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_finish)


func _show_slide(tex: Texture2D, min_size: Vector2, caption_text: String) -> void:
	_logo.texture = tex
	_logo.custom_minimum_size = min_size
	_caption.text = caption_text
	_caption.visible = caption_text != ""


func _input(event: InputEvent) -> void:
	if _done or not visible:
		return
	var skip := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		skip = true
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	finished.emit()
	queue_free()
