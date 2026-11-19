extends SceneTree
var main: Node
var game: Node
var shots: Array = []
var out_dir := "D:/GameSimulator/research/reports/ui_audit_20261120"
var words := RegEx.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(70).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = root.get_node("Game")
	words.compile("\\S+")
	UiPreferences.config_path = out_dir.path_join("unused_preferences.cfg")
	UiPreferences.values = UiPreferences.DEFAULTS.duplicate(true)
	game.saves = SaveService.new("D:/GameSimulator/.tmp/ui-audit-20261120/isolated-saves")
	main = load("res://src/app/main.tscn").instantiate()
	root.add_child(main)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	main.screens.close_screen()
	main.case_modal.hide()
	main._toast.hide()
	if not main._mode_3d:
		main._toggle_3d_mode()
	main._fit_home()
	await _frames(30)
	var before := JSON.stringify(game.world.to_dict(), "", true, true).sha256_text()
	await _capture("01_map_1600", main.hud)
	main.region_panel.show_region("35.78")
	await _capture("02_region_1600", main._ui)
	main.region_panel.show_context("province", "35")
	await _capture("03_province_1600", main._ui)
	main._toggle_budget()
	await _capture("04_budget_over_region_1600", main.budget_panel)
	main.budget_panel.hide()
	main.region_panel.show_region("")
	main._open_policy_context("province", "35")
	await _capture("05_policy_1600", main.policy_panel)
	main.policy_panel.hide()
	main._on_case_presented(game.pending_case())
	await _capture("06_case_1600", main.case_modal)
	main.case_modal.hide()
	root.size = Vector2i(1280, 720)
	main._fit_home()
	await _capture("07_map_1280", main.hud)
	main.region_panel.show_region("35.78")
	await _capture("08_region_1280", main._ui)
	main.region_panel.show_region("")
	main._on_case_presented(game.pending_case())
	await _capture("09_case_1280", main.case_modal)
	main.case_modal.hide()
	for screen in ["profile", "statistics", "report", "settings"]:
		main.screens.session_started = true
		main.screens.open(screen)
		await _capture("10_" + screen + "_1280", main.screens)
	var after := JSON.stringify(game.world.to_dict(), "", true, true).sha256_text()
	var file := FileAccess.open(out_dir.path_join("inventory.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"world_unchanged": before == after, "before": before, "after": after,
		"method": "Rendered Control bounds after viewport and ancestor clip intersections; full control text is an upper bound for partially clipped labels. Panel area is rectangle union, not opaque pixel coverage.",
		"shots": shots}, "  "))
	file.close()
	print("AUDIT snapshots: ", shots.size(), "; world unchanged: ", before == after)
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _visible_rect(control: Control) -> Rect2:
	var rect := _rect(control).intersection(root.get_visible_rect())
	var parent := control.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents:
			rect = rect.intersection(_rect(parent))
		parent = parent.get_parent()
	return rect

func _capture(name: String, surface: Node) -> void:
	await _frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	var texts: Array = []
	var panels: Array[Rect2] = []
	var duplicates := {}
	var total_words := 0
	var small := 0
	var viewport := root.get_visible_rect()
	var scale: float = float(root.size.x) / viewport.size.x
	var controls: Array = surface.find_children("*", "Control", true, false)
	if surface is Control:
		controls.append(surface)
	for node in controls:
		if not node.is_visible_in_tree():
			continue
		var visible := _visible_rect(node)
		if not visible.has_area():
			continue
		if node is PanelContainer:
			panels.append(visible)
		var text := ""
		if node is Label or node is RichTextLabel or node is Button:
			text = str(node.text).strip_edges()
		if text == "":
			continue
		var size: float = float(node.get_theme_font_size("font_size")) * scale
		var count := words.search_all(text).size()
		total_words += count
		if size < 12:
			small += 1
		duplicates[text] = int(duplicates.get(text, 0)) + 1
		var rect := _rect(node)
		texts.append({"path": str(node.get_path()), "text": text, "words": count,
			"effective_font_px": size, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"visible_rect": [visible.position.x, visible.position.y, visible.size.x, visible.size.y],
			"partially_clipped": not visible.grow(1).encloses(rect)})
	var overlaps: Array = []
	for i in texts.size():
		var a: Array = texts[i].visible_rect
		var ra := Rect2(a[0], a[1], a[2], a[3])
		for j in range(i + 1, texts.size()):
			var b: Array = texts[j].visible_rect
			var rb := Rect2(b[0], b[1], b[2], b[3])
			if ra.intersection(rb).get_area() > minf(ra.get_area(), rb.get_area()) * .2:
				overlaps.append([texts[i].text, texts[j].text])
	var occupied := 0
	var samples := 0
	for y in range(0, int(viewport.size.y), 10):
		for x in range(0, int(viewport.size.x), 10):
			samples += 1
			for rect in panels:
				if rect.has_point(Vector2(x + 5, y + 5)):
					occupied += 1
					break
	shots.append({"name": name, "window": str(root.size), "scope": str(surface.get_path()),
		"viewport": str(viewport.size), "text_blocks": texts.size(), "word_upper_bound": total_words,
		"text_blocks_under_12px": small, "panel_rect_coverage": float(occupied) / samples,
		"overlapping_text_candidates": overlaps, "repeated_exact_text": duplicates, "texts": texts})
	print("AUDIT ", name, ": ", texts.size(), " blocks / ", total_words, " words / ", small, " small / ", overlaps.size(), " overlap candidates")
