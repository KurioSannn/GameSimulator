class_name StoryPlayer
extends Control
## Full-screen, data-driven dialogue scene player (one owner of focus at a time).
## Beats come from Narrative.resolve(): {"s", "e", "t", "bg", "options", "set"}.
## Controls: click / Space / Enter = lanjut (finishes the line first), Esc = lewati adegan,
## H = riwayat, A = otomatis. Text speed and auto mode come from UiPreferences.
## While visible it swallows all input so the map and HUD cannot receive gameplay input.

signal finished
signal line_shown(index: int)
## Exact position in the scene after every step ({} when the scene ends); Main mirrors it into
## world.story.playing so any save, mid-dialogue included, resumes at this beat (D-094).
signal progressed(state: Dictionary)
signal save_requested

const SPEEDS := [28.0, 50.0, 110.0, 100000.0]  # Lambat, Normal, Cepat, Instan (characters/second)

var _beats: Array = []
var _index := -1
var _ctx: Dictionary = {}
var _done_cb: Callable
var _shown := 0.0
var _auto_wait := 0.0
var _auto := false
var _skippable := true
var _history: Array = []
var _waiting_option := false

var _backdrop: StoryBackdrop
var _portrait_left: StoryPortrait
var _portrait_right: StoryPortrait
var _panel: PanelContainer
var _name_plate: PanelContainer
var _name: Label
var _role: Label
var _text: RichTextLabel
var _cont: Label
var _options: VBoxContainer
var _auto_btn: Button
var _history_panel: PanelContainer
var _history_box: VBoxContainer
var _title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = StoryBackdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_portrait_left = StoryPortrait.new()
	_portrait_left.anchor_left = 0.03
	_portrait_left.anchor_right = 0.33
	_portrait_left.anchor_top = 0.14
	_portrait_left.anchor_bottom = 0.78
	add_child(_portrait_left)
	_portrait_right = StoryPortrait.new()
	_portrait_right.anchor_left = 0.67
	_portrait_right.anchor_right = 0.97
	_portrait_right.anchor_top = 0.14
	_portrait_right.anchor_bottom = 0.78
	add_child(_portrait_right)

	_title = UiKit.title("", 22, Color("fff4d2"))
	_title.position = Vector2(32, 24)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_title)

	var tools := UiKit.hbox(8)
	tools.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tools.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tools.offset_top = 20
	tools.offset_right = -24
	add_child(tools)
	var hist := UiKit.ghost_button(_k("Riwayat", "H"), _toggle_history, "Baca ulang percakapan")
	tools.add_child(hist)
	_auto_btn = UiKit.ghost_button(_k("Otomatis", "A"), _toggle_auto, "Lanjut otomatis setelah setiap kalimat")
	_auto_btn.toggle_mode = true
	tools.add_child(_auto_btn)
	var save := UiKit.ghost_button(_k("Simpan", "F5"), func(): save_requested.emit(), "Simpan permainan di kalimat ini")
	tools.add_child(save)
	var skip := UiKit.ghost_button(_k("Lewati", "Esc"), skip_scene, "Lewati adegan ini")
	skip.name = "SkipButton"
	tools.add_child(skip)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", GameSkin.frame())
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -236
	_panel.offset_bottom = -28
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var col := UiKit.vbox(6)
	_panel.add_child(col)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.fit_content = false
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", UiKit.font_size(25))
	_text.add_theme_color_override("default_color", UiKit.TEXT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text)
	_cont = UiKit.label("▼ ketuk untuk lanjut" if OS.has_feature("mobile") else "▼ klik / Spasi", 15, UiKit.MUTED)
	_cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_cont)

	_name_plate = PanelContainer.new()
	_name_plate.add_theme_stylebox_override("panel", StitchTheme.soft_box(Color("8a3b2a"), Color("4a2a1a"), 8, 16, 6, 2))
	_name_plate.anchor_left = 0.08
	_name_plate.anchor_top = 1.0
	_name_plate.anchor_bottom = 1.0
	_name_plate.offset_left = 28
	_name_plate.offset_top = -284
	_name_plate.offset_bottom = -240
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_plate)
	var nrow := UiKit.hbox(10)
	_name_plate.add_child(nrow)
	_name = UiKit.title("", 21, Color("fff4d2"))
	nrow.add_child(_name)
	_role = UiKit.label("", 15, Color("f4dcae"))
	_role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nrow.add_child(_role)

	_options = UiKit.vbox(10)
	_options.anchor_left = 0.3
	_options.anchor_right = 0.7
	_options.anchor_top = 1.0
	_options.anchor_bottom = 1.0
	_options.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_options.offset_bottom = -300
	add_child(_options)

	_history_panel = PanelContainer.new()
	_history_panel.add_theme_stylebox_override("panel", GameSkin.frame())
	_history_panel.anchor_left = 0.18
	_history_panel.anchor_right = 0.82
	_history_panel.anchor_top = 0.08
	_history_panel.anchor_bottom = 0.86
	add_child(_history_panel)
	var hv := UiKit.vbox(8)
	_history_panel.add_child(hv)
	var hh := UiKit.hbox(8)
	var ht := UiKit.title("RIWAYAT PERCAKAPAN", 22, UiKit.ACCENT)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(ht)
	hh.add_child(UiKit.ghost_button("Tutup", _toggle_history))
	hv.add_child(hh)
	var hs := ScrollContainer.new()
	hs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hv.add_child(hs)
	_history_box = UiKit.vbox(8)
	_history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hs.add_child(_history_box)
	_history_panel.hide()
	hide()


## Plays beats; `done` is called once when the scene ends (finished or skipped).
func play(beats: Array, ctx: Dictionary = {}, done: Callable = Callable(), opts: Dictionary = {}) -> void:
	_beats = beats.duplicate(true)
	_ctx = ctx
	_done_cb = done
	_index = -1
	_skippable = bool(opts.get("skippable", true))
	_title.text = str(opts.get("title", ""))
	_auto = bool(UiPreferences.values.get("auto_dialogue", false))
	_auto_btn.button_pressed = _auto
	find_child("SkipButton", true, false).visible = _skippable
	_backdrop.set_kind(str(opts.get("bg", ctx.get("bg", "ruang_kerja"))))
	_portrait_left.character = {}
	_portrait_right.character = {}
	_portrait_left.queue_redraw()
	_portrait_right.queue_redraw()
	if opts.has("history"):
		_history = (opts.history as Array).duplicate(true)
	show()
	if _beats.is_empty():
		_finish()
		return
	# Resume support: continue at a saved beat (its flags are re-applied, which is idempotent).
	_index = clampi(int(opts.get("start_index", 0)), 0, _beats.size() - 1) - 1
	if opts.has("start_index") and not _history.is_empty():
		_history.pop_back()  # the resumed line is appended again by _next()
	_next()
	if bool(opts.get("revealed", false)) and _index >= 0:
		_text.visible_characters = _text.get_total_character_count()
		_shown = float(_text.visible_characters)
		_on_line_complete()


## Everything needed to restore this exact moment of the scene.
func state() -> Dictionary:
	if not visible or _index < 0 or _index >= _beats.size():
		return {}
	return {
		"beats": _beats.duplicate(true), "index": _index, "title": _title.text, "skippable": _skippable,
		"bg": _backdrop.kind, "case": str(_ctx.get("case", "")),
		"revealed": _text.visible_characters >= _text.get_total_character_count(),
		"waiting_option": _waiting_option,
		"speaker": str(_beats[_index].get("s", "narasi")), "expression": str(_beats[_index].get("e", "netral")),
		"history": _history.slice(maxi(0, _history.size() - 60)),
	}


func is_playing() -> bool:
	return visible


func _next() -> void:
	if _waiting_option:
		return
	_index += 1
	if _index >= _beats.size():
		_finish()
		return
	var b: Dictionary = _beats[_index]
	if b.has("bg"):
		_backdrop.set_kind(str(b.bg))
	var who := str(b.get("s", "narasi"))
	# A beat may name its own case (legacy sequence: locals from several episodes in one scene).
	var rec: Dictionary = ContentDB.cases.get(str(b.case), {}) if b.has("case") else _ctx.get("case_record", {})
	var c: Dictionary = ContentDB.character(who, rec)
	var narrator := who == "narasi" or str(c.get("name", "")) == ""
	_name_plate.visible = not narrator
	_name.text = str(c.get("name", ""))
	_role.text = str(c.get("role", ""))
	if not narrator:
		var on_right := who == "nara"
		_name_plate.anchor_left = 0.92 if on_right else 0.08
		_name_plate.anchor_right = 0.92 if on_right else 0.08
		_name_plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN if on_right else Control.GROW_DIRECTION_END
		_name_plate.offset_left = -28 if on_right else 28
		_name_plate.offset_right = -28 if on_right else 28
		var target := _portrait_right if on_right else _portrait_left
		target.show_character(c, str(b.get("e", "netral")))
		target.modulate = Color.WHITE
		(_portrait_left if on_right else _portrait_right).modulate = Color(0.6, 0.6, 0.65, 0.85)
	_text.text = str(b.get("t", ""))
	_text.add_theme_color_override("default_color", Color("5a4a32") if narrator else UiKit.TEXT)
	_text.visible_characters = 0
	_shown = 0.0
	_auto_wait = 0.0
	_cont.visible = false
	UiKit.clear(_options)
	if Game.world != null:
		Narrative.apply_sets(Game.world, b)
	_history.append({"name": str(c.get("name", "")), "text": _text.text})
	line_shown.emit(_index)
	progressed.emit(state())


func _process(delta: float) -> void:
	if not visible or _index < 0 or _index >= _beats.size():
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_shown += delta * SPEEDS[int(UiPreferences.values.get("text_speed", 1))]
		_text.visible_characters = mini(total, int(_shown))
		if _text.visible_characters >= total:
			_on_line_complete()
		return
	if _auto and not _waiting_option and not _history_panel.visible:
		_auto_wait += delta
		if _auto_wait > 1.1 + total * 0.025:
			_next()


func _on_line_complete() -> void:
	var b: Dictionary = _beats[_index]
	if b.has("options") and not (b.options as Array).is_empty():
		_show_options(b.options)
	else:
		_cont.visible = true
	progressed.emit(state())


func _show_options(options: Array) -> void:
	_waiting_option = true
	UiKit.clear(_options)
	var n := 1
	for opt in options:
		var o: Dictionary = opt
		var btn := UiKit.button("%d. %s" % [n, str(o.get("t", ""))], func(): _pick_option(o), n == 1)
		btn.custom_minimum_size = Vector2(0, 50)
		btn.add_theme_font_size_override("font_size", UiKit.font_size(20))
		_options.add_child(btn)
		n += 1
	_options.get_child(0).grab_focus.call_deferred()


func _pick_option(o: Dictionary) -> void:
	if Game.world != null:
		Narrative.apply_sets(Game.world, o)
	_history.append({"name": "Pilihanmu", "text": str(o.get("t", ""))})
	var reply: Array = o.get("reply", [])
	for k in reply.size():
		_beats.insert(_index + 1 + k, reply[k])
	_waiting_option = false
	UiKit.clear(_options)
	GameAudio.play_ui("select")
	_next()


func advance() -> void:
	if _waiting_option or _history_panel.visible:
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_text.visible_characters = total
		_shown = float(total)
		_on_line_complete()
		return
	GameAudio.play_ui("click")
	_next()


func skip_scene() -> void:
	if not _skippable or not visible:
		return
	# Options still record nothing; flags stay unset, which every condition treats as "not chosen".
	_waiting_option = false
	_finish()


func _finish() -> void:
	progressed.emit({})
	hide()
	_history_panel.hide()
	UiKit.clear(_options)
	var cb := _done_cb
	_done_cb = Callable()
	finished.emit()
	if cb.is_valid():
		cb.call()


func _toggle_auto() -> void:
	_auto = not _auto
	_auto_btn.button_pressed = _auto


func _toggle_history() -> void:
	_history_panel.visible = not _history_panel.visible
	if _history_panel.visible:
		UiKit.clear(_history_box)
		for h in _history.slice(maxi(0, _history.size() - 80)):
			var row := UiKit.vbox(2)
			if str(h.name) != "":
				row.add_child(UiKit.title(str(h.name), 16, UiKit.ACCENT))
			row.add_child(UiKit.label(str(h.text), 17, UiKit.TEXT, true))
			_history_box.add_child(row)


func clear_history() -> void:
	_history.clear()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()
	elif event is InputEventMouseButton or event is InputEventGesture:
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				advance()
			KEY_ESCAPE:
				if _history_panel.visible:
					_toggle_history()
				else:
					skip_scene()
			KEY_H:
				_toggle_history()
			KEY_A:
				_toggle_auto()
			KEY_F5:
				save_requested.emit()
			KEY_1, KEY_2, KEY_3, KEY_4:
				if _waiting_option:
					var i := int((event as InputEventKey).keycode - KEY_1)
					if i < _options.get_child_count():
						(_options.get_child(i) as Button).pressed.emit()
	get_viewport().set_input_as_handled()


## Button label with its keyboard shortcut on desktop; touch devices show the word only.
static func _k(label: String, key: String) -> String:
	return label if OS.has_feature("mobile") else "%s (%s)" % [label, key]
