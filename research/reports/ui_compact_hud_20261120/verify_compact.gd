extends SceneTree
var main: Node
var game: Node
var content: Node
var shots: Array = []
var checks: Array = []
var out := "D:/GameSimulator/research/reports/ui_compact_hud_20261120"
var errors := AuditErrors.new()
class AuditErrors extends Logger:
	var messages: Array = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != ERROR_TYPE_WARNING: messages.append(rationale if rationale != "" else code)
func _initialize() -> void:
	OS.add_logger(errors)
	call_deferred("_run")
func _run() -> void:
	create_timer(100).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(out)
	game = root.get_node("Game")
	content = root.get_node("ContentDB")
	game.saves = SaveService.new(out.path_join("saves"))
	UiPreferences.config_path = out.path_join("preferences.cfg")
	UiPreferences.values = UiPreferences.DEFAULTS.duplicate(true)
	if game.pending_case() != "": game.decide(game.pending_case(), "b")
	game.advance_quarter()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	main = load("res://src/app/main.tscn").instantiate()
	root.add_child(main)
	main.case_modal.hide()
	main.screens.close_screen()
	main._toggle_3d_mode()
	main._fit_home()
	main._toast_panel.hide()
	await _frames(12)
	var before := _hash()
	var compact_panels: Array = []
	for window in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = window
		for scale in [1.0,1.1]:
			UiPreferences.values.text_scale = scale
			main._ui.get_child(0).theme = UiKit.make_theme()
			UiKit.rescale(main._ui)
			main._refresh_all()
			main.case_modal.hide()
			var suffix := "%d_%d" % [window.x,roundi(scale*100)]
			await _capture("pending_"+suffix,main.hud)
			compact_panels.append(_panels("pending_"+suffix))
			for id in content.cases:
				main.hud.refresh(game.world,id)
				await _frames(2)
				_check(main.hud._agenda_title.get_global_rect().end.x <= main.hud._agenda_btn.get_global_rect().position.x, "case title and action do not overlap "+id+" "+suffix)
				_check(root.get_visible_rect().encloses(main.hud._bottom_dock.get_global_rect()), "agenda stays inside window "+id+" "+suffix)
			main.hud.refresh(game.world, "")
			await _capture("ready_"+suffix,main.hud)
			compact_panels.append(_panels("ready_"+suffix))
			_check(not main.hud._agenda_text.visible and main.hud.next_btn.visible,"ready HUD shows one quarter action "+suffix)
			main.hud.map_tools_card.show()
			main.hud.atmosphere_controls.show()
			await _capture("tools_"+suffix,main.hud)
			main.hud.atmosphere_controls.hide()
			main.hud.map_tools_card.hide()
	main._refresh_all()
	main.case_modal.hide()
	await _click(_find_button(main.hud,"PETA"))
	_check(main.hud.map_tools_card.visible,"compact map button receives native input")
	await _click(_find_button(main.hud,"PETA"))
	var profile_button: Button = main.hud.get_node("Control/HBoxContainer/IdentitasHUD").get_child(0) if main.hud.has_node("Control/HBoxContainer/IdentitasHUD") else null
	if profile_button == null:
		for button in main.hud.find_children("*","Button",true,false):
			if button.tooltip_text.begins_with("Profil Presiden"): profile_button=button
	await _click(profile_button)
	_check(main.screens.visible and main.screens.active_screen=="profile","compact identity opens profile")
	main.screens.close_screen()
	_check(before==_hash(),"display scenarios and UI reads preserve world/RNG")
	var file := FileAccess.open(out.path_join("qa.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"shots":shots,"panels":compact_panels,"checks":checks,"runtime_errors":errors.messages,"world_unchanged":before==_hash()},"  "))
	file.close()
	var passed := checks.all(func(x):return bool(x.ok)) and errors.messages.is_empty()
	for check in checks:
		if not check.ok: print("FAIL ",check.label)
	print("Compact HUD: ",checks.size()," checks; passed: ",passed,"; errors: ",errors.messages.size())
	quit(0 if passed else 1)
func _panels(state: String) -> Dictionary:
	var result := {"state":state}
	for name in ["IdentitasHUD","IndikatorHUD","AgendaHUD","NavigasiHUD"]:
		var panel: Control = main.hud.find_child(name,true,false)
		result[name]=_array(_rect(panel))
	return result
func _capture(name: String, surface: Node, screenshot: bool = true) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	if screenshot:
		root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	var buttons: Array = []
	var textures: Array = []
	var frames: Array = []
	var stages: Array = []
	var viewport := root.get_visible_rect()
	var factor := float(root.size.x) / viewport.size.x
	for control in surface.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree() or control.modulate.a < 0.01:
			continue
		var rect := _rect(control)
		var visible := _visible(control)
		if not visible.has_area():
			continue
		if control is PresidentPortrait:
			stages.append({"art_rect": _array(control.art_rect), "contact_y": control.contact_y, "shadow_rect": _array(control.shadow_rect)})
			_check(is_equal_approx(control.art_rect.end.y, control.contact_y), name + " feet stay anchored")
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
		"text_scale": UiPreferences.values.text_scale, "screenshot": screenshot, "buttons": buttons, "frames": frames, "textures": textures, "stages": stages})
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
	# Wait for container reflow after dirty-state/style changes before targeting its new rectangle.
	await _frames(4)
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await _frames(2)
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

func _set_name(editor: PlayerNameEditor, value: String) -> void:
	# Fixture assignment emits the same change signal as typing; buttons/Enter use real viewport input.
	editor.field.text = value
	editor.field.text_changed.emit(editor.field.text)

func _texts(node: Node) -> String:
	var result := str(node.text) if node is Label else ""
	for child in node.get_children(): result += " " + _texts(child)
	return result
