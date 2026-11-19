class_name QaUiRuntime
extends Node
## Real window/input regression for the Figma integration. All writes isolated under --qa-ui.
var main: Node
var out_dir := ""
var checks: Array = []
var assets: Array = []
var errors := ErrorLog.new()


class ErrorLog extends Logger:
	var entries: Array = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			entries.append(rationale if rationale != "" else code)


func run() -> void:
	OS.add_logger(errors)
	get_tree().create_timer(45.0).timeout.connect(func(): printerr("UI QA timed out"); get_tree().quit(2))
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.saves = SaveService.new(out_dir.path_join("saves"))
	UiPreferences.config_path = out_dir.path_join("preferences.cfg")
	UiPreferences.values = UiPreferences.DEFAULTS.duplicate(true)
	main.get_window().mode = Window.MODE_WINDOWED
	main.get_window().size = Vector2i(1280, 720)
	main.case_modal.hide()
	main.screens.session_started = false
	main.screens.open("menu")
	await _frames(5)
	_check(main.screens.visible and not main.camera.is_processing(), "menu blocks map navigation")
	await _shot("menu_1280")
	await _click(_find(main.screens, "MULAI MANDAT BARU"))
	_check(not main.screens.visible and main.case_modal.visible, "new mandate opens the pending case")
	await _key(KEY_2)
	_check(main.case_modal._selected == "b" and Game.pending_case() != "", "selection alone does not decide")
	_check(not main.case_modal._confirm.disabled, "selected option enables confirmation")
	_check(_texts(main.case_modal._selection_detail).contains("Manfaat") and _texts(main.case_modal._selection_detail).contains("Risiko"), "selected option reveals benefits and risks before confirmation")
	await _shot("case_selected_1280")
	await _key(KEY_ENTER)
	_check(Game.pending_case() == "" and not main.case_modal.visible, "Enter confirms the selected decision")
	_check(Game.world.tick == 0, "decision does not advance time")
	main.region_panel.show_region("35.78")
	await _frames(4)
	_check(main.region_panel._model.name == "Kota Surabaya", "district selection reads its own identity")
	await _click(_find(main.region_panel, "Data"))
	await _click(_find(main.region_panel, "Sumber"))
	_check(main.sources_dialog.visible, "source button opens provenance dialog")
	_check(_texts(main.sources_dialog).contains("Tanggal publikasi") and _texts(main.sources_dialog).contains("Waktu pengambilan"), "provenance metadata is visible")
	await _shot("sources_1280")
	await _click(_find(main.sources_dialog, "×"))
	_check(not main.sources_dialog.visible, "source dialog closes")
	for context in [["province", "35"], ["island_group", "sulawesi"], ["province", "91"], ["kabkota", "11.01"]]:
		main.region_panel.show_context(context[0], context[1])
		await _frames(2)
		_check(main.region_panel._model.valid and main.region_panel._model.id == context[1], "context reset " + str(context))
		if context[0] != "kabkota":
			_check(main.region_panel.region_id == "", "aggregate context does not masquerade as district")
	main.region_panel.show_context("island_group", "sulawesi")
	_check(main.region_panel._model.facts.is_empty(), "group does not borrow provincial official facts")
	await _shot("group_1280")
	main.region_panel.show_context("province", "35")
	await _click(_find(main.region_panel, "Kebijakan"))
	_check(main.policy_panel.visible and main.policy_panel.context == {"type": "province", "id": "35"}, "policy retains selected resolution")
	main.policy_panel.hide()
	main.region_panel.show_region("")
	main._toggle_budget()
	await _frames(3)
	_check(main.budget_panel.visible and main.budget_panel.get_global_rect().get_center().x > 500, "budget dialog is above modal shade")
	await _click(_find(main.budget_panel, "✕"))
	_check(not main.budget_panel.visible, "budget close button receives mouse input")
	if Game.pending_case() != "":
		Game.decide(Game.pending_case(), "a")
	main.case_modal.hide()
	main._refresh_all()
	main._next_quarter()
	await _frames(5)
	_check(Game.world.tick == 3 and Game.last_quarter_reports.size() == 3, "quarter produces three real monthly observations")
	var before := _hash()
	_check(Game.save_to("ui_roundtrip", "UI QA") == "", "save succeeds in isolated directory")
	_check(Game.load_from("ui_roundtrip") == "" and _hash() == before, "save/load preserves exact simulation state")
	_check(Game.last_quarter_reports.is_empty(), "loaded save does not fabricate missing monthly history")
	main.case_modal.hide()
	main.screens.session_started = true
	for screen in ["profile", "statistics", "settings", "report"]:
		main.screens.open(screen)
		await _frames(4)
		_check(_buttons_fit(main.screens), screen + " primary controls fit at 1280×720")
		await _shot(screen + "_1280")
	_check(_hash() == before, "reading all screens does not change simulation or RNG")
	main.screens._origin = "map"
	main.screens.open("settings")
	await _frames(4)
	var settings: SettingsView
	settings = _settings(main.screens)
	_check(settings != null, "settings component is available")
	if settings != null:
		settings.pending.window_mode = 1
		settings.pending.resolution = 2
		settings.pending.text_scale = 1.1
		settings.pending.reduce_motion = true
		settings.pending.volume = 37.0
		settings.pending.pan_left = KEY_J
		settings._save()
		UiPreferences.read()
		_check(float(UiPreferences.values.volume) == 37.0 and UiPreferences.values.reduce_motion and int(UiPreferences.values.pan_left) == KEY_J, "preferences persist independently of saves")
		_check(absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.37) < 0.001, "master volume applies to actual audio bus")
	await _frames(4)
	for screen in ["profile", "statistics", "settings", "report"]:
		main.screens.open(screen)
		await _frames(4)
		_check(_buttons_fit(main.screens), screen + " primary controls fit at 110% text")
		await _shot(screen + "_110")
	main.get_window().size = Vector2i(1920, 1080)
	UiPreferences.values.text_scale = 1.0
	main.screens.open("profile")
	await _frames(5)
	await _shot("profile_1920")
	main.screens.close_screen()
	main.case_modal.hide()
	main.region_panel.show_context("province", "35")
	await _frames(5)
	await _shot("province_1920")
	var passed := checks.all(func(check): return bool(check.ok)) and errors.entries.is_empty()
	var file := FileAccess.open(out_dir.path_join("qa_ui.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "assets": assets,
		"save_dir": Game.saves.save_dir, "preferences_path": UiPreferences.config_path, "runtime_errors": errors.entries,
		"last_window": str(main.get_window().size)}, "  "))
	file.close()
	for check in checks:
		print("UI QA %s: %s" % ["PASS" if check.ok else "FAIL", check.label])
	get_tree().quit(0 if passed else 1)


func _settings(root: Node) -> SettingsView:
	if root is SettingsView:
		return root
	for child in root.get_children():
		var found := _settings(child)
		if found != null:
			return found
	return null


func _check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})


func _hash() -> String:
	return JSON.stringify(Game.world.to_dict(), "", true, true).sha256_text()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _find(root: Node, text: String) -> Button:
	if root is Button and root.text.begins_with(text):
		return root
	for child in root.get_children():
		var result := _find(child, text)
		if result != null:
			return result
	return null


func _texts(root: Node) -> String:
	var result := str(root.text) + "\n" if root is Label else ""
	for child in root.get_children():
		result += _texts(child)
	return result


func _click(button: Button) -> void:
	if button == null:
		_check(false, "click target exists")
		return
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames(2)


func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _buttons_fit(surface: Control) -> bool:
	var viewport := get_viewport().get_visible_rect()
	for control in surface.find_children("*", "Button", true, false):
		if not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		if not viewport.grow(2).encloses(rect):
			return false
	return true


func _shot(name: String) -> void:
	await _frames(3)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	for control in main._ui.find_children("*", "TextureRect", true, false):
		if control.is_visible_in_tree() and control.has_meta("figma_slot"):
			var rect: Rect2 = control.get_global_rect()
			var texture: Texture2D = control.texture
			var path: String = texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path
			assets.append({"shot": name, "screen": control.get_meta("figma_screen"),
				"slot": control.get_meta("figma_slot"), "path": path, "rect": str(rect)})
			_check(rect.size.x > 0 and rect.size.y > 0 and FileAccess.file_exists(path), "visible local asset " + str(control.get_meta("figma_slot")))
