class_name TutorialCoach
extends PanelContainer
## Contextual tutorial: one instruction at a time, advanced only when the player performs the
## action (data: game/data/story/tutorial.json). Progress lives in world.story.tutorial so it
## survives save/load; replayable from Pengaturan and Buku Kisah.

signal step_changed(step_id: String)
signal completed

var _who: Label
var _title: Label
var _text: Label
var _progress: Label
var _ack: Button
var _steps: Array = []


func _ready() -> void:
	add_theme_stylebox_override("panel", GameSkin.frame("panel_brown", 16, 16))
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 90
	offset_bottom = -110
	custom_minimum_size = Vector2(460, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := UiKit.vbox(6)
	add_child(col)
	var head := UiKit.hbox(8)
	_who = UiKit.subheader("", UiKit.ACCENT, 13)
	_who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_who)
	_progress = UiKit.subheader("", UiKit.MUTED, 12)
	head.add_child(_progress)
	head.add_child(UiKit.ghost_button("Lewati tutorial", skip_all, "Tutorial bisa diulang dari Pengaturan"))
	col.add_child(head)
	_title = UiKit.title("", 21, UiKit.TEXT)
	col.add_child(_title)
	_text = UiKit.label("", 17, UiKit.TEXT, true)
	_text.custom_minimum_size.x = 430  # fixed wrap width, so the panel's height follows the text
	col.add_child(_text)
	_ack = UiKit.button("MENGERTI", func(): notify("ack"), true)
	_ack.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(_ack)
	hide()


func _state() -> Dictionary:
	return Narrative.ensure(Game.world).tutorial


func active() -> bool:
	return Game.world != null and not bool(_state().get("done", true)) and _steps.size() > 0


func current_wait() -> String:
	if not active():
		return ""
	var i := int(_state().step)
	return str(_steps[i].wait) if i < _steps.size() else ""


func start(from_beginning := false) -> void:
	_steps = ContentDB.story.get("tutorial", {}).get("steps", [])
	var st := _state()
	if from_beginning:
		st["step"] = 0
	st["done"] = false
	_show_step()


func resume() -> void:
	_steps = ContentDB.story.get("tutorial", {}).get("steps", [])
	if active():
		_show_step()
	else:
		hide()


## Called by Main when the player performs an action (pan, zoom, region, agenda, decided, quarter, ack).
func notify(action: String) -> void:
	if not active():
		return
	var st := _state()
	var i := int(st.step)
	if i >= _steps.size() or str(_steps[i].wait) != action:
		return
	st["step"] = i + 1
	GameAudio.play_ui("confirm")
	if int(st.step) >= _steps.size():
		st["done"] = true
		hide()
		completed.emit()
		return
	_show_step()


func skip_all() -> void:
	var st := _state()
	st["done"] = true
	st["step"] = _steps.size()
	hide()
	completed.emit()


func set_suppressed(on: bool) -> void:
	visible = active() and not on


func _show_step() -> void:
	var i := int(_state().step)
	if i >= _steps.size():
		hide()
		return
	var s: Dictionary = _steps[i]
	var c: Dictionary = ContentDB.character(str(s.get("s", "laras")))
	_who.text = str(c.get("name", "")).to_upper()
	_title.text = str(s.get("title", ""))
	_text.text = str(s.get("t_mobile", s.get("t", ""))) if OS.has_feature("mobile") else str(s.get("t", ""))
	_progress.text = "%d / %d" % [i + 1, _steps.size()]
	_ack.visible = str(s.wait) == "ack"
	show()
	_fit.call_deferred()
	step_changed.emit(str(s.id))


## Shrink-wrap to the current text, keeping the bottom edge in place (the panel grows upward).
func _fit() -> void:
	var h := get_combined_minimum_size().y
	offset_top = offset_bottom - h
	size.y = h
