extends Node
## Desktop main screen wiring: map + top national bar + overlay selector + region panel +
## case modal + turn controls. Holds no gameplay state; reads Game.world, calls Game methods.
##
## Hotkeys: Space/Enter = lanjut kuartal · F5 = simpan cepat · F9 = muat cepat ·
##          Ctrl+S = simpan manual baru · Esc = tutup panel · Home = seluruh peta · 1-9 = pilihan kasus ·
##          C = peta perubahan kuartal terakhir · L = catatan peristiwa

var map_view: MapView
var camera: MapCamera
var map_view_3d: MapView3D
var camera_3d: MapCamera3D
var _mode_3d := false
var _mode_btn: Button
var region_panel: RegionPanel
var case_modal: CaseModal
var budget_panel: BudgetPanel
var policy_panel: PolicyPanel
var _ui: CanvasLayer
var _map_chrome: Control
var hud: Hud
var screens: DesktopScreens
var sources_dialog: SourcesDialog
var _modal_shade: ColorRect
var _period: Label  # alias of the HUD period label (QA checklist reads it)
var _indicators: HBoxContainer
var _legend: Label
var _lod_label: Label
var _tooltip: PanelContainer
var _tooltip_label: Label
var _toast_panel: PanelContainer
var _toast: Label
var _toast_tween: Tween
var _next_btn: Button
var _overlay := Overlays.DEFS[0]
var _change_mode := false        # map shows last quarter's change of the overlay variable
var _change_btn: CheckButton
var _weighting_label: Label
var _log_panel: PanelContainer
var _log_box: VBoxContainer
var _left_down := false
var _left_down_pos := Vector2.ZERO
var _is_panning := false


const FIGMA_ICONS := {
	"welfare": "imgIkonHeart",
	"sentiment": "imgIkonShield",
	"price_level": "imgIkonEconomy",
	"trust": "imgIkonTrust",
	"environment": "imgIkonLeaf",
	"fiscal_space": "imgIkonCoin",
}
var ready_ticks_ms := 0  # engine start -> main screen _ready (QA timing)


func _ready() -> void:
	UiPreferences.read()
	var automation := Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--screenshot=") or a.begins_with("--qa-") or a.begins_with("--map-bench="))
	if not automation:
		UiPreferences.apply(get_viewport())
	ready_ticks_ms = Time.get_ticks_msec()
	RenderingServer.set_default_clear_color(StitchTheme.color("sea").darkened(0.35))
	map_view = MapView.new()
	add_child(map_view)
	camera = MapCamera.new()
	add_child(camera)
	camera.make_current()
	var err := map_view.load_map()
	if err != "":
		push_error(err)
	print("map loaded in %d ms (%d regions, %s)" % [map_view.load_ms, map_view.region_ids.size(), map_view.active_lod])
	
	# 3D Tabletop Diorama map initialization
	map_view_3d = MapView3D.new()
	map_view_3d.name = "MapView3D"
	map_view_3d.visible = false
	add_child(map_view_3d)
	camera_3d = MapCamera3D.new()
	camera_3d.name = "Camera3D"
	camera_3d.current = false
	add_child(camera_3d)
	map_view_3d.setup(map_view)
	camera_3d.view_changed.connect(_on_view_changed)
	map_view.lod_changed.connect(func(l_name, _r): if map_view_3d: map_view_3d.set_active_lod(l_name))
	_build_ui()
	camera.view_changed.connect(_on_view_changed)
	camera.fit(map_view.bounds, get_viewport().get_visible_rect().size)
	# LOD2/LOD3 parse on worker threads once the first frame is on screen (measured: avoids a ~105 ms
	# first-zoom stall without delaying the first frame).
	RenderingServer.frame_post_draw.connect(map_view.preload_remaining, CONNECT_ONE_SHOT)
	Game.month_advanced.connect(func(_r): pass)
	Game.world_replaced.connect(_refresh_all)
	Game.case_presented.connect(_on_case_presented)
	Game.case_resolved.connect(func(_c, _ch): _refresh_all())
	Game.policy_enacted.connect(func(_p): _refresh_all())
	_refresh_all()
	if not automation:
		_toggle_3d_mode()
	var pend := Game.pending_case()
	if pend != "":
		_on_case_presented(pend)
	if not automation:
		case_modal.hide()
		screens.open("menu")
	else:
		screens.session_started = true
	_sync_interaction()
	_debug_automation()


## Dev/QA automation: `-- --screenshot=<path> [--decide=<choice>] [--quarters=N] [--select=<region>]
## [--view=<lon>,<lat>,<metres per pixel>] [--focus-province=<id>]`
## renders the real windowed game, saves a PNG, and quits. Not used in normal play.
func _debug_automation() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("qa-checklist"):
		var qa := QaChecklist.new()
		qa.main = self
		qa.out_dir = args["qa-checklist"]
		add_child(qa)
		qa.run()
		return
	if args.has("qa-ui"):
		var qa := QaUiRuntime.new()
		qa.main = self
		qa.out_dir = str(args["qa-ui"])
		add_child(qa)
		qa.run()
		return
	if args.has("qa-diorama"):
		var qa := QaDiorama.new()
		qa.main = self
		qa.out_dir = str(args["qa-diorama"])
		add_child(qa)
		qa.run()
		return
	if args.has("map-bench"):
		var bench := QaMapBench.new()
		bench.main = self
		bench.out_dir = args["map-bench"]
		add_child(bench)
		bench.run()
		return
	if not args.has("screenshot"):
		return
	if args.has("window"):
		var dimensions := str(args.window).split("x")
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(int(dimensions[0]), int(dimensions[1]))
		await get_tree().process_frame
	print("UI QA window=%s viewport=%s" % [get_window().size, get_viewport().get_visible_rect().size])
	Game.saves = SaveService.new(ProjectSettings.globalize_path("res://../.tmp/ui-qa-saves").simplify_path())
	await get_tree().process_frame
	if args.has("3d"):
		_toggle_3d_mode()
	if args.has("hide-case"):
		case_modal.visible = false
	if args.has("play-to"):  # --play-to=<case_id> [--choices=<case_id>:<choice>,...] (others: first choice)
		var picks := {}
		for kv in str(args.get("choices", "")).split(",", false):
			picks[kv.split(":")[0]] = kv.split(":")[1]
		while Game.pending_case() != args["play-to"] and not Game.world.is_term_over():
			var pend := Game.pending_case()
			if pend != "":
				case_modal._choose(picks.get(pend, str(ContentDB.cases[pend].choices[0].choice_id)))
			_next_quarter()
		case_modal.present(args["play-to"])
	if args.has("decide") and Game.pending_case() != "":
		case_modal._choose(args.decide)
	for _q in int(args.get("quarters", "0")):
		_next_quarter()
	if args.has("view"):  # --view=<lon>,<lat>,<metres per pixel>
		var v: PackedStringArray = args.view.split(",")
		camera.position = MapView.project_lonlat(float(v[0]), float(v[1]))
		camera.zoom = Vector2.ONE * (MapView.KM_PER_UNIT * 1000.0 / float(v[2]))
		camera.view_changed.emit()
	if args.has("focus-province"):
		_view_province(args["focus-province"])
	if args.has("select"):
		if _mode_3d and map_view_3d:
			map_view_3d.set_selected(args.select)
			var r := map_view.region_rect(args.select)
			if r.size != Vector2.ZERO and camera_3d:
				camera_3d.focus_region(r, false)
		map_view.set_selected(args.select)
		region_panel.show_region(args.select)
	if args.has("context"):
		var context: PackedStringArray = str(args.context).split(":", true, 1)
		region_panel.show_context(context[0], context[1])
	if args.has("budget"):
		budget_panel.open()
	if args.has("policy"):
		policy_panel.region_id = region_panel.region_id
		policy_panel._selected = args.policy
		policy_panel.open()
	if args.has("overlay"):
		for d in Overlays.DEFS:
			if d.id == args.overlay:
				_set_overlay(d)
	if args.has("change"):
		_change_btn.button_pressed = true
	if args.has("log"):
		_toggle_log()
	if args.has("screen"):
		if args.screen == "sources":
			sources_dialog.open(region_panel._model)
		else:
			screens.open(args.screen)
	for _f in 8:
		await get_tree().process_frame
	var tex := get_viewport().get_texture()
	var img := tex.get_image() if tex else null
	if img != null:
		img.save_png(args.screenshot)
		print("screenshot saved: ", args.screenshot)
	get_tree().quit()


func _build_ui() -> void:
	get_window().min_size = Vector2i(1280, 720)
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.make_theme()
	_ui.add_child(root)
	_map_chrome = Control.new()
	_map_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_map_chrome)

	# Stitch-style HUD (sidebar, stat cards, agenda, big CTA). See ui/hud.gd.
	hud = Hud.new()
	_map_chrome.add_child(hud)
	_indicators = hud.indicators
	_period = hud._term
	_weighting_label = hud.weighting_label
	_legend = hud.legend
	_lod_label = hud.lod_label
	_change_btn = hud.change_btn
	_next_btn = hud.next_btn
	_mode_btn = hud.mode_btn
	hud.next_pressed.connect(_next_quarter)
	hud.policy_pressed.connect(_toggle_policy)
	hud.budget_pressed.connect(_toggle_budget)
	hud.log_pressed.connect(_toggle_log)
	hud.decision_pressed.connect(func(): if Game.pending_case() != "": case_modal.present(Game.pending_case()))
	hud.legacy_pressed.connect(func(): screens._origin = "map"; screens.open("legacy"))
	hud.overlay_selected.connect(_set_overlay)
	hud.change_toggled.connect(func(on: bool): _change_mode = on; _recolor(); _clear_map_focus())
	hud.zoom_pressed.connect(_zoom_by)
	hud.home_pressed.connect(_fit_home)
	hud.mode_3d_pressed.connect(_toggle_3d_mode)
	hud.menu_selected.connect(_on_menu)
	hud.context_requested.connect(func(kind, id): region_panel.show_context(kind, id))
	hud.time_mode_selected.connect(func(mode: String):
		if map_view_3d:
			map_view_3d.set_time_mode(mode))
	hud.weather_mode_selected.connect(func(mode: String):
		if map_view_3d:
			map_view_3d.set_weather_mode(mode))
	# Region panel (docked cleanly in the middle-right zone, strictly above the bottom dock).
	region_panel = RegionPanel.new()
	region_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	region_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	region_panel.offset_left = -446
	region_panel.offset_top = 112
	region_panel.offset_right = -16
	region_panel.offset_bottom = 112
	_map_chrome.add_child(region_panel)
	region_panel.province_view_requested.connect(_view_province)
	region_panel.sources_requested.connect(func(model): sources_dialog.open(model))
	region_panel.policy_requested.connect(_open_policy_context)
	region_panel.case_requested.connect(func(id): case_modal.present(id))
	region_panel.visibility_changed.connect(func():
		hud.right_col.visible = not region_panel.visible
		if _tooltip != null: _tooltip.hide())

	# Hover tooltip placeholder moved after _log_panel below so hover cards never draw beneath logs.
	_toast_panel = PanelContainer.new()
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", GameSkin.frame("panel_brown", 16, 16))
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.offset_top = 92
	_toast_panel.offset_left = -420
	_toast_panel.offset_right = 420
	_toast = UiKit.label("", 13, UiKit.ACCENT, true)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.custom_minimum_size.x = 320
	_toast.visibility_changed.connect(func(): if not _toast.visible: _toast_panel.visible = false)
	_toast_panel.add_child(_toast)
	_toast_panel.modulate.a = 0.0
	_toast_panel.visible = false
	_map_chrome.add_child(_toast_panel)

	# Budget panel (floats in centered modal layer).
	budget_panel = BudgetPanel.new()

	# Event log (docked cleanly next to the left rail, above the bottom dock).
	_log_panel = PanelContainer.new()
	_log_panel.theme_type_variation = "PanelDock"
	_log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_log_panel.offset_left = 188
	_log_panel.offset_bottom = -112
	_log_panel.custom_minimum_size = Vector2(540, 0)
	var lv := UiKit.vbox(10)
	_log_panel.add_child(lv)
	var lh := UiKit.hbox(8)
	var lt := UiKit.title("CATATAN PERISTIWA", 17, UiKit.ACCENT)
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(lt)
	lh.add_child(UiKit.subheader("TERBARU DI ATAS", UiKit.MUTED, 11))
	var lclose := UiKit.ghost_button("✕", func(): _log_panel.visible = false, "Tutup catatan (L)")
	lclose.custom_minimum_size = Vector2(32, 30)
	lh.add_child(lclose)
	lv.add_child(lh)
	lv.add_child(HSeparator.new())
	var ls := ScrollContainer.new()
	ls.custom_minimum_size = Vector2(510, 270)
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(ls)
	_log_box = UiKit.vbox(10)
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(_log_box)
	_log_panel.visible = false
	_map_chrome.add_child(_log_panel)

	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_theme_stylebox_override("panel", GameSkin.frame("panel_brown", 14, 16))
	_tooltip_label = UiKit.label("", 13)
	_tooltip.add_child(_tooltip_label)
	_tooltip.visible = false
	_map_chrome.add_child(_tooltip)
	region_panel.mouse_entered.connect(func(): _tooltip.hide())
	_log_panel.mouse_entered.connect(func(): _tooltip.hide())

	# Modal shade + centered modal containers (must sit above docks and map tooltips).
	_modal_shade = ColorRect.new()
	_modal_shade.color = Color(0.02, 0.04, 0.11, 0.74)
	_modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_shade.hide()
	root.add_child(_modal_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	case_modal = CaseModal.new()
	case_modal.map_lod = map_view.lod("lod1")
	center.add_child(case_modal)
	policy_panel = PolicyPanel.new()
	center.add_child(policy_panel)
	center.add_child(budget_panel)
	sources_dialog = SourcesDialog.new()
	center.add_child(sources_dialog)
	for modal in [case_modal, policy_panel, budget_panel, sources_dialog]:
		modal.visibility_changed.connect(_sync_interaction)
	case_modal.decided.connect(_on_decided)
	case_modal.region_data_requested.connect(func(id: String): map_view.set_selected(id); region_panel.show_region(id))
	screens = DesktopScreens.new()
	screens.map_lod = map_view.lod("lod1")
	root.add_child(screens)
	screens.started.connect(_start_session)
	screens.closed.connect(_sync_interaction)
	screens.visibility_changed.connect(_sync_interaction)
	screens.region_selected.connect(func(id): map_view.set_selected(id); region_panel.show_region(id); screens.visited[id] = true)
	screens.preferences_changed.connect(func(): root.theme = UiKit.make_theme(); UiKit.rescale(root); _refresh_all())


func _unhandled_input(event: InputEvent) -> void:
	if screens != null and screens.visible:
		return
	if _modal_shade != null and _modal_shade.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			case_modal.hide()
			policy_panel.hide()
			budget_panel.hide()
			sources_dialog.hide()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_left_down = true
				_left_down_pos = mb.position
				_is_panning = false
			else:
				var was_panning := _is_panning
				_left_down = false
				_is_panning = false
				if not was_panning:
					_handle_map_click(mb.position, mb.double_click)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _left_down:
			if not _is_panning and (mm.position - _left_down_pos).length() > 5.0:
				_is_panning = true
			if _is_panning:
				if _mode_3d and camera_3d:
					camera_3d.drag_pan_step(mm.position - mm.relative, mm.position)
				elif camera:
					camera.position -= mm.relative / camera.zoom.x
					camera.view_changed.emit()
				return
		
		# Normal hover update
		var id: String
		if _mode_3d and map_view_3d and camera_3d:
			id = map_view_3d.region_at_ray(camera_3d, mm.position)
			map_view_3d.set_hovered(id)
		else:
			var wp := map_view.get_canvas_transform().affine_inverse() * mm.position
			id = map_view.region_at(wp)
		map_view.set_hovered(id)
		_update_tooltip(id, mm.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: _next_quarter()
			KEY_F5: _quicksave()
			KEY_B: _toggle_budget()
			KEY_P: _toggle_policy()
			KEY_T: _toggle_3d_mode()
			KEY_C: _change_btn.button_pressed = not _change_btn.button_pressed
			KEY_L: _toggle_log()
			KEY_F9: _quickload()
			KEY_ESCAPE:
				if _mode_3d and map_view_3d:
					map_view_3d.set_selected("")
				map_view.set_selected("")
				region_panel.show_region("")
				_clear_map_focus()
			KEY_S:
				if k.ctrl_pressed or k.meta_pressed:
					_manual_save()


func _handle_map_click(screen_pos: Vector2, is_double_click: bool) -> void:
	var id: String
	if _mode_3d and map_view_3d and camera_3d:
		id = map_view_3d.region_at_ray(camera_3d, screen_pos)
		map_view_3d.set_selected(id)
		if id != "" and is_double_click:
			var r := map_view.region_rect(id)
			if r.size != Vector2.ZERO:
				camera_3d.focus_region(r, true)
	else:
		var wp := map_view.get_canvas_transform().affine_inverse() * screen_pos
		id = map_view.region_at(wp)
		if id != "" and is_double_click:
			var r := map_view.region_rect(id)
			if r.size != Vector2.ZERO:
				camera.focus_rect(r, get_viewport().get_visible_rect().size)
	
	map_view.set_selected(id)
	region_panel.show_region(id)
	_clear_map_focus()
	if id != "":
		screens.visited[id] = true
	if policy_panel.visible:
		policy_panel.context = {}
		policy_panel.region_id = id
		policy_panel.refresh()


func _update_tooltip(id: String, screen_pos: Vector2) -> void:
	var over_log := _log_panel.visible and _log_panel.get_global_rect().has_point(screen_pos)
	var over_reg := region_panel.visible and region_panel.get_global_rect().has_point(screen_pos)
	if id == "" or case_modal.visible or over_log or over_reg:
		_tooltip.visible = false
		return
	var r: Dictionary = ContentDB.region_by_id[id]
	var i: int = Game.world.region_index[id]
	var val := Game.world.get_v("sentiment", i)
	var line2 := "Sentimen: %s" % Game.sim.sentiment_state(val).label
	if _overlay.var != "" and _overlay.var != "sentiment":
		line2 += " · %s: %s" % [_overlay.label, Fmt.num(Game.world.get_v(_overlay.var, i), 1)]
	if _change_mode and _overlay.var != "":
		var d := SimLedger.deltas(Game.world, _overlay.var)
		if not d.is_empty():
			line2 += "\nPerubahan %s kuartal terakhir: %s" % [_overlay.label, Fmt.signed(d[i], 2)]
	_tooltip_label.text = "%s\n%s" % [RegionPanel._display_name(r), line2]
	_tooltip.reset_size()
	var vp := get_viewport().get_visible_rect().size
	var pos := screen_pos + Vector2(18, 18)
	var right_edge := region_panel.position.x - 12.0 if region_panel.visible else vp.x - 12.0
	pos.x = clampf(pos.x, 110.0, maxf(110.0, right_edge - _tooltip.size.x))
	pos.y = clampf(pos.y, 98.0, maxf(98.0, vp.y - 112.0 - _tooltip.size.y))
	_tooltip.position = pos
	_tooltip.visible = true


func _set_overlay(d: Dictionary) -> void:
	_overlay = d
	for i in Overlays.DEFS.size():
		if Overlays.DEFS[i].id == d.id:
			hud.layer_select.select(i)
	_recolor()
	_clear_map_focus()


func _recolor() -> void:
	var w := Game.world
	map_view_3d.set_landscape(_overlay.id == "landscape")
	map_view_3d.sync_cases(ContentDB.cases, w.case_state)
	if _overlay.ramp == "landscape":
		map_view.recolor(func(_id): return Color("85ad58"))
		map_view_3d.sync_colors()
		_legend.text = "Tampilan diorama Indonesia. Pilih lapisan data di atas."
		_legend.tooltip_text = "Peta 3D/2D menampilkan kontur wilayah Indonesia."
		return
	if _overlay.ramp == "categorical":
		map_view.recolor(func(id): return Overlays.ISLAND_COLORS.get(ContentDB.region_by_id[id].island_group, Color.GRAY))
		_legend.text = "Pembagian kawasan pulau untuk navigasi cepat."
		_legend.tooltip_text = "Pengelompokan pulau untuk mempermudah penjelajahan (bukan pembagian resmi provinsi)."
		if map_view_3d:
			map_view_3d.sync_colors()
		return
	var v: String = _overlay.var
	var uncal := PackedByteArray()
	uncal.resize(w.region_count())
	var n_uncal := 0
	for i in w.region_count():
		if ContentDB.region_baseline_status(v, i) == "UNCALIBRATED":
			uncal[i] = 1
			n_uncal += 1
	var hatch := " Arsir menandai data awal netral simulasi (%d wilayah)." % n_uncal if n_uncal > 0 else ""
	if _change_mode:
		var d := SimLedger.deltas(w, v)
		if d.is_empty():
			map_view.recolor(func(_id): return Overlays.change_color(0.0, 1.0))
			_legend.text = "Tren %s: belum ada data kuartal." % _overlay.label
			_legend.tooltip_text = ""
			if map_view_3d:
				map_view_3d.sync_colors()
			return
		var scale := Overlays.change_scale(d)
		map_view.recolor(func(id):
			var i: int = w.region_index[id]
			var col := Overlays.change_color(d[i], scale)
			return Overlays.uncalibrated(col) if uncal[i] == 1 else col)
		_legend.text = "Tren %s (Bln %d–%d): Biru turun · Oranye naik" % [_overlay.label, int(w.ledger.start_tick) + 1, w.tick]
		_legend.tooltip_text = "Skala warna ±%s %s" % [Fmt.num(scale, 1), hatch]
		if map_view_3d:
			map_view_3d.sync_colors()
		return
	var arr: PackedFloat64Array = w.vars[v]
	map_view.recolor(func(id):
		var i: int = w.region_index[id]
		var col := Overlays.color(_overlay, arr[i])
		return Overlays.uncalibrated(col) if uncal[i] == 1 else col)
	_legend.text = "%s: %s (rendah) → %s (tinggi)" % [_overlay.label, Fmt.num(_overlay.min, 0), Fmt.num(_overlay.max, 0)]
	_legend.tooltip_text = "Indikator wilayah.%s" % hatch
	if map_view_3d:
		map_view_3d.sync_colors()


func _refresh_all() -> void:
	var w := Game.world
	hud.refresh(w, Game.pending_case())
	UiKit.clear(_indicators)
	var n: Dictionary = Game.sim.national_summary(w)
	var has_q := SimLedger.active(w)
	# National indicators are aggregated from the 514 regional states; ▲▼ = change over the last quarter.
	for spec in [["Kesejahteraan", "welfare"], ["Sentimen", "sentiment"], ["Harga", "price_level"], ["Kepercayaan", "trust"], ["Lingkungan", "environment"], ["Anggaran", "fiscal_space"]]:
		var key: String = spec[1]
		if key not in Hud.PINNED_INDICATORS:
			continue
		var val: float = float(w.national.get("fiscal_space", 0.0)) if key == "fiscal_space" else float(n[key])
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		box.set_meta("indicator_key", key)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var outer := UiKit.hbox(8)
		outer.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(outer)
		var ic := FigmaAssets.picture(3, FIGMA_ICONS[key], Vector2(24, 24))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		outer.add_child(ic)
		var col := UiKit.vbox(1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		outer.add_child(col)
		var row := UiKit.hbox(6)
		var suffix := "%" if key == "trust" else " / 100" if key in ["welfare", "sentiment", "environment"] else ""
		row.add_child(UiKit.number(Fmt.num(val, 1) + suffix, 23))
		if has_q:
			var prev: float = float(w.ledger.get("fiscal_space_start", val)) if key == "fiscal_space" else w.weighted_mean_of(w.ledger.start[key])
			var diff := val - prev
			if absf(diff) >= 0.05:
				var good := diff < 0.0 if key == "price_level" else diff > 0.0
				var dcol := UiKit.SUCCESS if good else UiKit.DANGER
				row.add_child(UiKit.label("%s %s" % ["▲" if diff > 0.0 else "▼", Fmt.num(absf(diff), 1)], 11, dcol))
		col.add_child(row)
		if key == "fiscal_space":
			box.tooltip_text = "Anggaran nasional (poin). Perubahan kuartal terakhir."
		else:
			box.tooltip_text = "%s · %s. Perubahan kuartal terakhir." % [spec[0], ChangeText.weighting_label(w.national_weighting())]
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		_indicators.add_child(box)
	_weighting_label.text = "Bobot penduduk" if w.national_weighting() == "population" else "Bobot setara 514 wilayah"
	_weighting_label.tooltip_text = "Agregasi indikator nasional menggunakan " + ChangeText.weighting_label(w.national_weighting()) + "."
	_next_btn.disabled = Game.pending_case() != "" or w.is_term_over()
	_recolor()
	if map_view_3d:
		map_view_3d.sync_climate_from_world(w)
	_clear_map_focus()
	region_panel.refresh()
	_refresh_log()


func _refresh_log() -> void:
	if not _log_panel.visible or _log_box == null:
		return
	UiKit.clear(_log_box)
	var entries: Array = Game.world.event_log
	if entries.is_empty():
		_log_box.add_child(UiKit.label("Belum ada peristiwa. Keputusan dan ringkasan kuartal akan muncul di sini.", 14, UiKit.MUTED, true))
		return
	for k in range(entries.size() - 1, maxi(-1, entries.size() - 13), -1):
		var ev := ChangeText.entry_card(entries[k])
		var card := PanelContainer.new()
		card.theme_type_variation = "PanelCard"
		var cv := UiKit.vbox(8)
		card.add_child(cv)

		# Card Header: Badge + When + Title
		var chead := UiKit.hbox(8)
		var bcol := UiKit.ACCENT
		match str(ev.badge_key):
			"danger": bcol = UiKit.DANGER
			"info": bcol = UiKit.INFO
			"real": bcol = UiKit.REAL
			"muted": bcol = UiKit.MUTED
		chead.add_child(UiKit.tag(str(ev.badge), bcol, 10))
		chead.add_child(UiKit.subheader(str(ev.when), UiKit.MUTED, 11))
		var t := UiKit.title(str(ev.title), 15, UiKit.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chead.add_child(t)
		cv.add_child(chead)

		if str(ev.subtitle) != "":
			cv.add_child(UiKit.label(str(ev.subtitle), 13, UiKit.MUTED, true))

		var rows: Array = ev.rows
		if not rows.is_empty():
			cv.add_child(HSeparator.new())
			for r in rows:
				var rline := UiKit.hbox(8)
				var vcol := UiKit.SUCCESS if str(r.tone) == "good" else UiKit.DANGER
				var rlbl := UiKit.label("%s (%s)" % [str(r.label), str(r.where)], 13, UiKit.TEXT, true)
				rlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rline.add_child(rlbl)
				rline.add_child(UiKit.tag("%s · %s" % [str(r.delta), str(r.when)], vcol, 11))
				cv.add_child(rline)
		_log_box.add_child(card)


func _toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible
	_refresh_log()


func _next_quarter() -> void:
	if case_modal.visible or _next_btn.disabled:
		return
	Game.advance_quarter()
	var msg := "Kuartal selesai."
	_toast_msg(msg)
	_refresh_all()
	if not Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--screenshot=") or a.begins_with("--qa-") or a.begins_with("--map-bench=")):
		screens.open("report")


func _on_case_presented(id: String) -> void:
	_tooltip.visible = false
	_focus_case(id)  # the map behind the modal shows where the case happens
	if screens == null or not screens.visible or screens.active_screen != "menu":
		case_modal.present(id)
	_refresh_all()


func _focus_case(case_id: String) -> void:
	var c: Dictionary = ContentDB.cases[case_id]
	if c.get("focus_regions", []).is_empty():
		return
	var rect := map_view.region_rect(c.focus_regions[0])
	for id in c.focus_regions:
		rect = rect.merge(map_view.region_rect(id))
	if _mode_3d and camera_3d:
		camera_3d.focus_rect(rect, get_viewport().get_visible_rect().size)
	else:
		camera.focus_rect(rect, get_viewport().get_visible_rect().size)


func _on_decided(case_id: String, choice_id: String) -> void:
	var err := Game.decide(case_id, choice_id)
	var msg := err
	if err == "":
		msg = "Keputusan dicatat."
		for k in range(Game.world.event_log.size() - 1, -1, -1):
			var e: Dictionary = Game.world.event_log[k]
			if str(e.kind) == "decision" and str(e.get("case_id", "")) == case_id:
				msg = ChangeText.decision_toast(e)
				break
	_toast_msg(msg)
	_focus_case(case_id)
	_refresh_all()


func _toggle_policy() -> void:
	if policy_panel.visible:
		policy_panel.visible = false
	else:
		if region_panel.visible:
			_open_policy_context(region_panel.context_kind, region_panel.context_id)
		else:
			_open_policy_context("national", "ID")


func _toggle_budget() -> void:
	if budget_panel.visible:
		budget_panel.visible = false
	else:
		budget_panel.open()


func _on_menu(id: String) -> void:
	match id:
		"save_quick": _quicksave()
		"load_quick": _quickload()
		"save_new": _manual_save()
		"log": _toggle_log()
		"profile", "statistics", "report", "legacy", "settings", "menu", "saves":
			screens._origin = "map"
			screens.open(id)


func _zoom_by(factor: float) -> void:
	if _mode_3d and camera_3d:
		camera_3d.distance = clampf(camera_3d.distance / factor, camera_3d.min_distance, camera_3d.max_distance)
		camera_3d._apply_transform()
		camera_3d.view_changed.emit()
	elif camera:
		camera._zoom_at(factor, get_viewport().get_visible_rect().size / 2)
	_clear_map_focus()


func _fit_home() -> void:
	var vp := get_viewport().get_visible_rect().size
	if _mode_3d and camera_3d:
		camera_3d.fit(map_view.bounds, vp)
	elif camera:
		camera.fit(map_view.bounds, vp)
	_clear_map_focus()


func _quicksave() -> void:
	var err := Game.save_to(SaveService.QUICKSAVE_ID, "Simpan Cepat")
	_toast_msg(err if err != "" else "Tersimpan (simpan cepat).")


func _quickload() -> void:
	var err := Game.load_from(SaveService.QUICKSAVE_ID)
	if err == "":
		_start_session()
	_toast_msg(err if err != "" else "Simpan cepat dimuat.")


func _manual_save() -> void:
	var id := "manual_" + Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var err := Game.save_to(id, "Simpanan " + Fmt.period(Game.world))
	_toast_msg(err if err != "" else "Tersimpan sebagai slot baru.")


func _toggle_3d_mode() -> void:
	_mode_3d = not _mode_3d
	if _mode_3d:
		map_view.visible = false
		camera.enabled = false
		map_view_3d.visible = true
		camera_3d.current = true
		camera_3d.make_current()
		camera_3d.fit(map_view.bounds, get_viewport().get_visible_rect().size)
		map_view_3d.sync_colors()
		if _mode_btn:
			_mode_btn.text = "2D (T)"
		_on_view_changed()
		_toast_msg("Peta 3D")
	else:
		map_view_3d.visible = false
		camera_3d.current = false
		map_view.visible = true
		camera.enabled = true
		camera.make_current()
		if _mode_btn:
			_mode_btn.text = "3D (T)"
		_on_view_changed()
		_toast_msg("Peta 2D")
	_sync_interaction()


func _on_view_changed() -> void:
	if _mode_3d and camera_3d:
		var approx_zoom := 1200.0 / maxf(camera_3d.distance, 1.0)
		map_view.update_view(approx_zoom)
		map_view_3d.update_view(approx_zoom)
		var m_per_px := MapView.KM_PER_UNIT * 1000.0 / approx_zoom
		var level: String = {"lod1": "Nasional", "lod2": "Provinsi", "lod3": "Kab/Kota"}.get(map_view.active_lod, "?")
		_lod_label.text = "%s (%s) · 3D" % [level, map_view.active_lod.to_upper()]
		_lod_label.tooltip_text = "Resolusi tampilan: ~%s / piksel" % (("%s km" % Fmt.num(m_per_px / 1000.0, 2)) if m_per_px >= 1000.0 else ("%d m" % roundi(m_per_px)))
	else:
		map_view.update_view(camera.zoom.x)
		var m_per_px := MapView.KM_PER_UNIT * 1000.0 / camera.zoom.x
		var level: String = {"lod1": "Nasional", "lod2": "Provinsi", "lod3": "Kab/Kota"}.get(map_view.active_lod, "?")
		_lod_label.text = "%s (%s)" % [level, map_view.active_lod.to_upper()]
		_lod_label.tooltip_text = "Resolusi tampilan: ~%s / piksel" % (("%s km" % Fmt.num(m_per_px / 1000.0, 2)) if m_per_px >= 1000.0 else ("%d m" % roundi(m_per_px)))


## Zoom to a province (the "higher administrative view" of a selected kab/kota).
func _view_province(province_id: String) -> void:
	var rect := map_view.province_rect(province_id)
	if rect.size != Vector2.ZERO:
		if _mode_3d and camera_3d:
			camera_3d.focus_rect(rect, get_viewport().get_visible_rect().size)
		else:
			camera.focus_rect(rect, get_viewport().get_visible_rect().size)
	_clear_map_focus()


func _toast_msg(msg: String) -> void:
	_toast.text = msg
	_toast.visible = true
	_toast_panel.reset_size()
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	if bool(UiPreferences.values.reduce_motion):
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(_toast_panel):
				_toast_panel.visible = false)
		return
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.8)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.45)
	_toast_tween.tween_callback(func(): _toast_panel.visible = false)


func _open_policy_context(kind: String, id: String) -> void:
	policy_panel.region_id = id if kind == "kabkota" else ""
	policy_panel.context = {"type": kind, "id": id}
	policy_panel._target_type = kind
	policy_panel.open()


func _start_session() -> void:
	region_panel.show_region("")
	policy_panel.hide()
	budget_panel.hide()
	sources_dialog.hide()
	case_modal.hide()
	if Game.pending_case() != "":
		_on_case_presented(Game.pending_case())
	_refresh_all()
	_sync_interaction()


func _sync_interaction() -> void:
	if case_modal == null or policy_panel == null or sources_dialog == null or screens == null:
		return
	var modal := case_modal.visible or policy_panel.visible or budget_panel.visible or sources_dialog.visible
	_modal_shade.visible = modal
	var blocked := modal or screens.visible
	_map_chrome.visible = not blocked
	if blocked and _toast_panel != null:
		_toast_panel.visible = false
	camera.set_process(not blocked and not _mode_3d)
	camera.set_process_unhandled_input(not blocked and not _mode_3d)
	camera_3d.set_process(not blocked and _mode_3d)
	camera_3d.set_process_unhandled_input(not blocked and _mode_3d)
	_tooltip.visible = false
	if modal and not screens.visible:
		for surface in [case_modal, policy_panel, budget_panel, sources_dialog]:
			if surface.visible:
				UiKit.trap_focus.call_deferred(surface)
	elif not blocked:
		_clear_map_focus()


func _clear_map_focus() -> void:
	if case_modal == null or screens == null or policy_panel == null or budget_panel == null or sources_dialog == null:
		return
	if case_modal.visible or policy_panel.visible or budget_panel.visible or sources_dialog.visible or screens.visible:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var fo := vp.gui_get_focus_owner()
	if fo != null:
		fo.release_focus()
