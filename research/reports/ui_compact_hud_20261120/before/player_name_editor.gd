class_name PlayerNameEditor
extends VBoxContainer
## Device player identity; never changes the fictional president or simulation state.
signal saved
var field: LineEdit
var save_button: Button
var cancel_button: Button
var feedback: Label

func _init() -> void:
	add_theme_constant_override("separation", 12)
	var row := UiKit.hbox(14)
	row.add_child(FigmaAssets.avatar(2, Vector2(56, 56)))
	var entry := UiKit.vbox(6)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(UiKit.title("NAMA PEMAIN", 18, UiKit.ACCENT))
	field = LineEdit.new()
	field.name = "NamaPemain"
	field.text = str(UiPreferences.values.player_name)
	field.placeholder_text = "Masukkan nama"
	field.max_length = 30
	field.custom_minimum_size.y = 48
	field.tooltip_text = "Ubah nama pemain · Enter untuk menyimpan"
	field.add_theme_stylebox_override("normal", StitchTheme.soft_box(Color("fff5dc"), Color("a48151"), 4, 12, 8, 2))
	field.add_theme_stylebox_override("focus", StitchTheme.soft_box(Color("fff9e9"), UiKit.ACCENT, 4, 12, 8, 2))
	entry.add_child(field)
	row.add_child(entry)
	add_child(row)
	var actions := UiKit.hbox(10)
	save_button = UiKit.button("SIMPAN NAMA", _save, true)
	save_button.name = "SimpanNama"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(save_button)
	cancel_button = UiKit.ghost_button("BATAL", _cancel, "Kembalikan nama yang tersimpan")
	cancel_button.name = "BatalNama"
	cancel_button.custom_minimum_size.x = 88
	actions.add_child(cancel_button)
	add_child(actions)
	feedback = UiKit.label("", 22, UiKit.MUTED, true)
	feedback.name = "StatusNama"
	feedback.custom_minimum_size.y = 28
	add_child(feedback)
	field.text_changed.connect(func(_text): _sync())
	field.text_submitted.connect(func(_text): _save())
	_sync()

func _sync() -> void:
	var dirty := field.text != str(UiPreferences.values.player_name)
	save_button.disabled = not dirty
	cancel_button.disabled = not dirty
	feedback.text = "Belum disimpan" if dirty else ""
	feedback.tooltip_text = ""
	feedback.add_theme_color_override("font_color", UiKit.MUTED)

func _save() -> void:
	if save_button.disabled:
		return
	var next := UiPreferences.values.duplicate(true)
	var normalized := field.text.strip_edges()
	next.player_name = normalized if normalized != "" else "Pemain"
	var error := UiPreferences.write(next)
	if error != OK:
		feedback.text = "Nama belum tersimpan. Coba lagi."
		feedback.tooltip_text = error_string(error)
		feedback.add_theme_color_override("font_color", UiKit.DANGER)
		return
	field.text = str(UiPreferences.values.player_name)
	_sync()
	feedback.text = "✓ Nama tersimpan"
	feedback.add_theme_color_override("font_color", UiKit.SUCCESS)
	saved.emit()

func _cancel() -> void:
	field.text = str(UiPreferences.values.player_name)
	_sync()
