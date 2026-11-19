extends SceneTree
var main: Node
var game: Node
var content: Node
var checks: Array = []
var out := "D:/GameSimulator/research/reports/ui_implementation_20261120/clarity"
var errors := AuditErrors.new()

class AuditErrors extends Logger:
	var messages: Array = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != ERROR_TYPE_WARNING:
			messages.append(rationale if rationale != "" else code)

func _initialize() -> void:
	OS.add_logger(errors)
	call_deferred("_run")

func _run() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(out)
	game = root.get_node("Game")
	content = root.get_node("ContentDB")
	game.saves = SaveService.new("D:/GameSimulator/.tmp/ui-implementation-20261120/clarity-saves")
	UiPreferences.config_path = "D:/GameSimulator/.tmp/ui-implementation-20261120/clarity-prefs.cfg"
	UiPreferences.values = UiPreferences.DEFAULTS.duplicate(true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	main = load("res://src/app/main.tscn").instantiate()
	root.add_child(main)
	main.case_modal.hide()
	main.screens.close_screen()
	main._toggle_3d_mode()
	main._fit_home()
	main._toast_panel.hide()
	await _frames(12)
	var before := _hash()
	main.screens.open("menu")
	await _shot("menu_live_3d_1280")
	_check(_find(main.screens, "MULAI MANDAT BARU") != null, "live-map menu retains new-mandate action")
	main.screens.close_screen()
	await _click(_find(main.hud, "PETA"))
	_check(main.hud.map_tools_card.visible, "native map-tools button opens the tool card")
	await _click(_find(main.hud, "Suasana & informasi"))
	_check(main.hud.time_select.is_visible_in_tree() and main.hud.weather_select.is_visible_in_tree(), "optional time/weather controls remain reachable")
	main.hud.time_select.select(4)
	main.hud.time_select.item_selected.emit(4)
	main.hud.weather_select.select(1)
	main.hud.weather_select.item_selected.emit(1)
	_check(main.map_view_3d.time_mode == "malam" and main.map_view_3d.weather_mode == "hujan", "UI previews reach the existing map time/weather integration")
	await _shot("map_tools_1280")
	main.hud.time_select.select(0)
	main.hud.time_select.item_selected.emit(0)
	main.hud.weather_select.select(0)
	main.hud.weather_select.item_selected.emit(0)
	main.hud.map_tools_card.hide()
	for context in [["kabkota", "35.78"], ["province", "35"], ["island_group", "sulawesi"], ["national", "ID"], ["province", "91"], ["kabkota", "11.01"]]:
		main.region_panel.show_context(context[0], context[1])
		await _frames(4)
		_check(main.region_panel._model.valid and main.region_panel._model.id == context[1], "region identity reset " + str(context))
		_check(main.region_panel._tab == "kondisi", "new region context resets the visible tab " + str(context))
		await _click(_find(main.region_panel, "Aktivitas"))
		_check(main.region_panel._tab == "aktivitas", "activity tab receives mouse input " + str(context))
		await _click(_find(main.region_panel, "Data"))
		_check(main.region_panel._tab == "data", "data tab receives mouse input " + str(context))
	await _shot("region_data_1280")
	main.region_panel.show_region("")
	main.case_modal.present("CASE-0001")
	await _frames(5)
	_check(not main._map_chrome.visible, "case hides underlying HUD and drawers")
	await _click(_find(main.case_modal, "Laporan lengkap"))
	_check(main.case_modal._context_details.visible and not main.case_modal._facts_preview.visible, "full report replaces the preview without repeating it")
	await _shot("case_sources_1280")
	main.case_modal.close_modal()
	_check(main._map_chrome.visible, "closing case restores the map UI")
	for scale in [1.0, 1.1]:
		UiPreferences.values.text_scale = scale
		main._ui.get_child(0).theme = UiKit.make_theme()
		UiKit.rescale(main._ui)
		for id in content.cases:
			main.case_modal.present(id)
			await _frames(6)
			_check(_inside_window(main.case_modal) and _inside_window(main.case_modal._confirm), "%s modal/confirmation fit at %d%%" % [id, roundi(scale * 100)])
			if not _inside_window(main.case_modal):
				print("MODAL BOUNDS ", id, " ", main.case_modal.get_global_rect(), " viewport ", root.get_visible_rect())
				await _shot("overflow_" + id + "_" + str(roundi(scale * 100)))
			var fits := true
			for entry in main.case_modal._cards:
				var card: Button = entry[1]
				for label in card.find_children("*", "Label", true, false):
					if not card.get_global_rect().grow(2).encloses(label.get_global_rect()):
						fits = false
					if label.has_meta("choice_cost_value") and str(label.text).length() <= 12:
						var font: Font = label.get_theme_font("font")
						var required := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
						if label.size.x + 1 < required: fits = false
			_check(fits, "%s choice labels stay inside their card at %d%%" % [id, roundi(scale * 100)])
			for choice in content.cases[id].choices:
				main.case_modal._select(str(choice.choice_id))
				await _frames(3)
				_check(_inside_window(main.case_modal) and _inside_window(main.case_modal._confirm), "%s selected %s fits at %d%%" % [id, choice.choice_id, roundi(scale * 100)])
		main.case_modal.hide()
		main.policy_panel.region_id = ""
		main.policy_panel.context = {"type": "province", "id": "35"}
		for id in content.policies:
			main.policy_panel._selected = id
			main.policy_panel.open()
			await _frames(4)
			var enact := _find(main.policy_panel, "TETAPKAN KEBIJAKAN")
			_check(_inside_window(main.policy_panel) and enact != null and _inside_window(enact), "%s program and enact action fit at %d%%" % [id, roundi(scale * 100)])
		main.policy_panel.hide()
		main.budget_panel.open()
		await _frames(4)
		_check(_inside_window(main.budget_panel) and _inside_window(_find(main.budget_panel, "TERAPKAN ANGGARAN")), "budget and pinned apply action fit at %d%%" % roundi(scale * 100))
		main.budget_panel.hide()
	_check(_hash() == before, "all UI reads and display previews preserve exact world/RNG serialization")
	UiPreferences.values.text_scale = 1.0
	main._ui.get_child(0).theme = UiKit.make_theme()
	UiKit.rescale(main._ui)
	main._fit_home()
	main.screens.open("menu")
	root.size = Vector2i(1920, 1080)
	await _shot("menu_live_3d_1920")
	var passed := errors.messages.is_empty() and checks.all(func(item): return bool(item.ok))
	var file := FileAccess.open(out.path_join("qa.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "runtime_errors": errors.messages,
		"world_before": before, "world_after": _hash(), "case_count": content.cases.size(),
		"policy_count": content.policies.size()}, "  "))
	file.close()
	for check in checks:
		if not check.ok: print("FAIL ", check.label)
	print("Clarity QA: ", checks.size(), " checks; passed: ", passed, "; runtime errors: ", errors.messages.size())
	quit(0 if passed else 1)

func _check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})

func _hash() -> String:
	return JSON.stringify(game.world.to_dict(), "", true, true).sha256_text()

func _inside_window(control: Control) -> bool:
	return control != null and root.get_visible_rect().grow(2).encloses(control.get_global_rect())

func _find(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix) and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var result := _find(child, prefix)
		if result != null: return result
	return null

func _click(button: Control) -> void:
	if button == null:
		_check(false, "required control exists")
		return
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)

func _frames(count: int) -> void:
	for index in count: await process_frame

func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
