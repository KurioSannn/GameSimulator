extends SceneTree
## Audit only. Device preferences/save fixtures are redirected; production UI is never patched.
var main: Node
var game: Node
var content: Node
var shots: Array = []
var checks: Array = []
var fixture_actions: Array = []
var out := "D:/GameSimulator/research/reports/ui_spacing_audit_20261120"
var errors := AuditErrors.new()

class AuditErrors extends Logger:
	var messages: Array = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != ERROR_TYPE_WARNING:
			messages.append(rationale if rationale != "" else code)

func _initialize() -> void:
	OS.add_logger(errors)
	call_deferred("_run")

func _run() -> void:
	create_timer(150).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(out)
	game = root.get_node("Game")
	content = root.get_node("ContentDB")
	game.saves = SaveService.new("D:/GameSimulator/.tmp/ui-spacing-audit-20261120/saves")
	UiPreferences.config_path = "D:/GameSimulator/.tmp/ui-spacing-audit-20261120/preferences.cfg"
	DirAccess.make_dir_recursive_absolute("D:/GameSimulator/.tmp/ui-spacing-audit-20261120")
	UiPreferences.values = UiPreferences.DEFAULTS.duplicate(true)
	var pending: String = game.pending_case()
	if pending != "":
		_check(game.decide(pending, "b") == "", "isolated Q2 fixture decision succeeds")
		fixture_actions.append("decide " + pending + " b in isolated process")
	game.advance_quarter()
	fixture_actions.append("advance one quarter in isolated process")
	_check(game.save_to("audit_fixture", "Simpanan uji audit") == "", "fixture save stays in audit-only directory")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	main = load("res://src/app/main.tscn").instantiate()
	root.add_child(main)
	main.case_modal.hide()
	main.screens.close_screen()
	main._toggle_3d_mode()
	main._fit_home()
	main._toast_panel.hide()
	await _frames(20)
	var before := _hash()
	var name_only := Array(OS.get_cmdline_user_args()).has("--qa-name-only")
	var windows: Array = [] if name_only else [Vector2i(1280, 720), Vector2i(1920, 1080)]
	for window in windows:
		root.size = window
		for scale in [1.0, 1.1]:
			UiPreferences.values.text_scale = scale
			main._ui.get_child(0).theme = UiKit.make_theme()
			UiKit.rescale(main._ui)
			var suffix := "%d_%d" % [window.x, roundi(scale * 100)]
			main.case_modal.hide()
			main.region_panel.show_region("")
			main.screens.close_screen()
			main._toast_panel.hide()
			await _capture("hud_" + suffix, main.hud)
			for screen in ["profile", "statistics", "settings", "report", "help", "saves", "new", "legacy", "menu"]:
				main.screens.open(screen)
				await _capture(screen + "_" + suffix, main.screens, screen in ["profile", "report", "settings", "menu"])
			main.screens.close_screen()
			for case_id in ["CASE-0001", "CASE-0006", "CASE-0008"]:
				main.case_modal.present(case_id)
				await _capture(case_id + "_" + suffix, main.case_modal, case_id == "CASE-0006")
				main.case_modal._select("b")
				await _capture(case_id + "_selected_" + suffix, main.case_modal, false)
			main.case_modal.hide()
			main.budget_panel.open()
			await _capture("budget_" + suffix, main.budget_panel)
			main.budget_panel.hide()
			main._open_policy_context("province", "35")
			await _capture("policy_" + suffix, main.policy_panel)
			main.policy_panel.hide()
			main.region_panel.show_context("province", "35")
			await _capture("region_" + suffix, main.region_panel)
			main.region_panel._tab = "data"
			main.region_panel.refresh()
			main.sources_dialog.open(main.region_panel._model)
			await _capture("sources_" + suffix, main.sources_dialog)
			main.sources_dialog.hide()
			main.region_panel.show_region("")
	root.size = Vector2i(1600, 900)
	UiPreferences.values.text_scale = 1.0
	main._ui.get_child(0).theme = UiKit.make_theme()
	UiKit.rescale(main._ui)
	main.screens.open("profile")
	await _frames(5)
	var name_edit := _find_name_edit(main.screens)
	_check(name_edit != null and name_edit.editable and name_edit.max_length == 30, "player name input exists, editable, max 30 characters")
	if name_edit != null:
		await _click(name_edit)
		name_edit.text = "Galih Uji Audit"
		await _click(_find_button(main.screens, "SIMPAN NAMA PEMAIN"))
		UiPreferences.read()
		_check(UiPreferences.values.player_name == "Galih Uji Audit", "native save-name button persists the name in isolated preferences")
		main.screens.open("statistics")
		main.screens.open("profile")
		await _frames(4)
		name_edit = _find_name_edit(main.screens)
		_check(name_edit.text == "Galih Uji Audit", "saved player name survives reopening the profile")
		await _capture("profile_name_saved_1600", main.screens)
		name_edit.text = ""
		await _click(_find_button(main.screens, "SIMPAN NAMA PEMAIN"))
		_check(UiPreferences.values.player_name == "Pemain" and name_edit.text == "", "empty name normalizes in storage but leaves field blank until reopened")
		await _capture("profile_empty_name_after_save_1600", main.screens)
		name_edit.text = "Nama Belum Disimpan"
		await _click(name_edit)
		await _key(KEY_ENTER)
		_check(UiPreferences.values.player_name == "Pemain", "Enter on name field does not submit the profile")
		var save := _find_button(main.screens, "SIMPAN NAMA PEMAIN")
		_check(save != null and not save.disabled, "save button remains enabled without dirty/saved status")
	var after := _hash()
	_check(before == after, "UI inspection/name edits preserve world serialization after fixture creation")
	var file := FileAccess.open(out.path_join("name_checks.json" if name_only else "inventory.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture_actions": fixture_actions, "world_before": before, "world_after": after,
		"world_unchanged_after_fixture": before == after, "checks": checks, "runtime_errors": errors.messages,
		"method": "Visible button rectangles versus nearest textured-panel slice-safe rectangle. Slice margins are a conservative visual-safe-area proxy, not measured painted-edge contours. Clipped scroll children are classified separately. Logical coordinates convert by window/viewport scale.",
		"shots": shots}, "  "))
	file.close()
	print("SPACING AUDIT: ", shots.size(), " states; ", checks.size(), " feature observations; errors: ", errors.messages.size())
	quit(0 if errors.messages.is_empty() else 1)

func _capture(name: String, surface: Node, screenshot: bool = true) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	if screenshot:
		root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	var buttons: Array = []
	var textures: Array = []
	var frames: Array = []
	var viewport := root.get_visible_rect()
	var factor := float(root.size.x) / viewport.size.x
	for control in surface.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree() or control.modulate.a < 0.01:
			continue
		var rect := _rect(control)
		var visible := _visible(control)
		if not visible.has_area():
			continue
		if control is BaseButton:
			var record := {"path": str(control.get_path()), "text": str(control.text), "rect": _array(rect), "visible_rect": _array(visible),
				"partially_clipped": not visible.grow(1).encloses(rect), "outside_viewport": not viewport.grow(1).encloses(rect)}
			var ancestor := control.get_parent()
			while ancestor != null:
				if ancestor is PanelContainer:
					var style: StyleBox = ancestor.get_theme_stylebox("panel")
					if style is StyleBoxTexture:
						var bounds := _rect(ancestor)
						var margins := _texture_margins(style)
						var safe := bounds.grow_individual(-margins[0], -margins[1], -margins[2], -margins[3])
						record["frame_path"] = str(ancestor.get_path())
						record["frame_rect"] = _array(bounds)
						record["slice_safe_rect"] = _array(safe)
						record["slice_margins"] = margins
						record["edge_distances"] = [rect.position.x - bounds.position.x, rect.position.y - bounds.position.y, bounds.end.x - rect.end.x, bounds.end.y - rect.end.y]
						record["safe_area_candidate"] = not safe.grow(1).encloses(visible)
						record["outside_frame_rect"] = not bounds.grow(1).encloses(visible)
						break
				ancestor = ancestor.get_parent()
			buttons.append(record)
		if control is PanelContainer:
			var style: StyleBox = control.get_theme_stylebox("panel")
			if style is StyleBoxTexture:
				frames.append({"path": str(control.get_path()), "rect": _array(rect), "texture": style.texture.resource_path,
					"content_margins": [style.get_content_margin(SIDE_LEFT), style.get_content_margin(SIDE_TOP), style.get_content_margin(SIDE_RIGHT), style.get_content_margin(SIDE_BOTTOM)], "slice_margins": _texture_margins(style)})
		if control is TextureRect and control.texture != null:
			var texture: Texture2D = control.texture
			var resource: String = texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path
			var entry := {"path": str(control.get_path()), "rect": _array(rect), "texture": resource,
				"texture_size": str(texture.get_size()), "stretch_mode": control.stretch_mode}
			if control.has_meta("figma_slot"): entry["slot"] = control.get_meta("figma_slot")
			textures.append(entry)
	shots.append({"name": name, "window": str(root.size), "viewport": str(viewport.size), "output_scale": factor,
		"text_scale": UiPreferences.values.text_scale, "screenshot": screenshot, "buttons": buttons, "frames": frames, "textures": textures})
	print("AUDIT ", name, ": ", buttons.size(), " visible buttons")

func _texture_margins(style: StyleBoxTexture) -> Array:
	return [style.get_texture_margin(SIDE_LEFT), style.get_texture_margin(SIDE_TOP), style.get_texture_margin(SIDE_RIGHT), style.get_texture_margin(SIDE_BOTTOM)]

func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _visible(control: Control) -> Rect2:
	var rect := _rect(control).intersection(root.get_visible_rect())
	var parent := control.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents: rect = rect.intersection(_rect(parent))
		parent = parent.get_parent()
	return rect

func _array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix) and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var button := _find_button(child, prefix)
		if button != null: return button
	return null

func _find_name_edit(node: Node) -> LineEdit:
	if node is LineEdit: return node
	for child in node.get_children():
		var edit := _find_name_edit(child)
		if edit != null: return edit
	return null

func _click(control: Control) -> void:
	if control == null:
		_check(false, "required click target exists")
		return
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)

func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)

func _hash() -> String:
	return JSON.stringify(game.world.to_dict(), "", true, true).sha256_text()

func _check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})

func _frames(count: int) -> void:
	for index in count: await process_frame
