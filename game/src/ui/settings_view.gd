class_name SettingsView
extends VBoxContainer
## Clean four-card device settings screen. Fits cleanly at both 1280x720 (110% scale) and 1920x1080.

signal saved
signal cancelled
var pending: Dictionary
var _binding := ""
var _binding_button: Button
var _grid: GridContainer


func _ready() -> void:
	pending = UiPreferences.values.duplicate(true)
	add_theme_constant_override("separation", 14)
	_build()


func _section(title: String, icon: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "PanelCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := UiKit.vbox(10)
	panel.add_child(body)

	var head := UiKit.hbox(10)
	head.add_child(FigmaAssets.picture(4, icon, Vector2(22, 22)))
	head.add_child(UiKit.title(title, 20, UiKit.ACCENT))
	body.add_child(head)
	body.add_child(HSeparator.new())
	_grid.add_child(panel)
	return body


func _build() -> void:
	UiKit.clear(self)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_grid)

	var audio := _section("AUDIO", "imgIkonSpeaker")
	for spec in [["VOLUME UTAMA", "volume"], ["MUSIK", "music"], ["EFEK SUARA", "effects"], ["DIALOG", "dialog"]]:
		var row := UiKit.hbox(12)
		var label := UiKit.label(spec[0], 15, UiKit.TEXT)
		label.custom_minimum_size.x = 170
		row.add_child(label)
		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = float(pending[spec[1]])
		row.add_child(slider)
		var value := UiKit.title(Fmt.num(slider.value, 0) + "%", 17, UiKit.ACCENT)
		value.custom_minimum_size.x = 58
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		var key: String = spec[1]
		slider.value_changed.connect(func(v): pending[key] = v; value.text = Fmt.num(v, 0) + "%")
		audio.add_child(row)

	var display := _section("TAMPILAN DAN BAHASA", "imgIkonScreen")
	_option(display, "MODE LAYAR", "window_mode", ["Layar penuh", "Jendela"])
	_option(display, "RESOLUSI JENDELA", "resolution", ["1920 × 1080", "1600 × 900", "1280 × 720"])
	_option(display, "ANTIALIASING PETA 3D", "antialiasing", ["Nonaktif", "2×", "4×"])
	var language := UiKit.hbox(12)
	language.add_child(UiKit.label("BAHASA", 15, UiKit.TEXT))
	language.add_child(UiKit.spacer())
	language.add_child(UiKit.tag("BAHASA INDONESIA", UiKit.ACCENT, 13))
	display.add_child(language)

	var controls := _section("KONTROL", "imgIkonKeyboard")
	var keys := UiKit.hbox(14)
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	for spec in [["KIRI", "pan_left"], ["KANAN", "pan_right"], ["ATAS", "pan_up"], ["BAWAH", "pan_down"]]:
		var key: String = spec[1]
		var col := UiKit.vbox(5)
		col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var kl := UiKit.label(spec[0], 11, UiKit.MUTED)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(kl)
		var button := Button.new()
		button.text = OS.get_keycode_string(int(pending[key]))
		button.custom_minimum_size = Vector2(68, 44)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func(): _binding = key; _binding_button = button; button.text = "TEKAN…")
		col.add_child(button)
		keys.add_child(col)
	controls.add_child(keys)
	controls.add_child(UiKit.label("Klik tombol arah untuk mengubahnya (Esc batal). Spasi: lanjut kuartal · Scroll: zoom · Home: seluruh peta.", 13, UiKit.MUTED, true))

	var access := _section("AKSESIBILITAS", "imgIkonEye")
	var scale := UiKit.hbox(12)
	var slbl := UiKit.label("SKALA TEKS", 15, UiKit.TEXT)
	slbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale.add_child(slbl)
	var select := OptionButton.new()
	select.custom_minimum_size.x = 140
	select.add_item("100%")
	select.add_item("110%")
	select.selected = 1 if float(pending.text_scale) > 1.0 else 0
	select.item_selected.connect(func(i): pending.text_scale = 1.0 if i == 0 else 1.1)
	scale.add_child(select)
	access.add_child(scale)

	var mrow := UiKit.hbox(12)
	var mlbl := UiKit.label("KURANGI GERAKAN", 15, UiKit.TEXT)
	mlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(mlbl)
	var motion := CheckButton.new()
	motion.text = "Aktif" if bool(pending.reduce_motion) else "Nonaktif"
	motion.button_pressed = bool(pending.reduce_motion)
	motion.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	motion.toggled.connect(func(on):
		pending.reduce_motion = on
		motion.text = "Aktif" if on else "Nonaktif")
	mrow.add_child(motion)
	access.add_child(mrow)

	var foot := UiKit.hbox(12)
	var reset_btn := UiKit.ghost_button("SETELAN AWAL", func():
		pending = UiPreferences.DEFAULTS.duplicate(true)
		pending.player_name = UiPreferences.values.player_name
		_build())
	reset_btn.custom_minimum_size.y = 44
	foot.add_child(reset_btn)
	foot.add_child(UiKit.spacer())
	var cancel_btn := UiKit.ghost_button("BATAL", func(): cancelled.emit())
	cancel_btn.custom_minimum_size = Vector2(110, 44)
	foot.add_child(cancel_btn)
	var save_btn := UiKit.button("SIMPAN PENGATURAN", _save, true)
	save_btn.custom_minimum_size = Vector2(210, 44)
	foot.add_child(save_btn)
	add_child(foot)


func _option(body: VBoxContainer, label: String, key: String, items: Array) -> void:
	var row := UiKit.hbox(12)
	var name := UiKit.label(label, 15, UiKit.TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var select := OptionButton.new()
	select.custom_minimum_size.x = 240
	select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for item in items:
		select.add_item(item)
	select.selected = int(pending[key])
	select.item_selected.connect(func(i): pending[key] = i)
	row.add_child(select)
	body.add_child(row)


func _save() -> void:
	var err := UiPreferences.write(pending)
	if err != OK:
		add_child(UiKit.label("Gagal menyimpan pengaturan: " + error_string(err), 15, UiKit.WARN))
		return
	UiPreferences.apply(get_viewport())
	saved.emit()


func _input(event: InputEvent) -> void:
	if _binding == "" or not is_visible_in_tree() or not event is InputEventKey or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE:
		_binding_button.text = OS.get_keycode_string(int(pending[_binding]))
		_binding = ""
		return
	if key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_P, KEY_B, KEY_T, KEY_C, KEY_L, KEY_S, KEY_F5, KEY_F9, KEY_HOME]:
		return
	for other in ["pan_left", "pan_right", "pan_up", "pan_down"]:
		if other != _binding and int(pending[other]) == key:
			return
	pending[_binding] = key
	_binding_button.text = OS.get_keycode_string(key)
	_binding = ""
