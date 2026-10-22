extends Node
## Desktop main screen wiring: map + top national bar + overlay selector + region panel +
## case modal + turn controls. Holds no gameplay state; reads Game.world, calls Game methods.
##
## Hotkeys: Space/Enter = lanjut kuartal · F5 = simpan cepat · F9 = muat cepat ·
##          Ctrl+S = simpan manual baru · Esc = tutup panel · Home = seluruh peta · 1-9 = pilihan kasus ·
##          C = peta perubahan kuartal terakhir · L = catatan peristiwa

var map_view: MapView
var camera: MapCamera
var region_panel: RegionPanel
var case_modal: CaseModal
var budget_panel: BudgetPanel
var policy_panel: PolicyPanel
var _ui: CanvasLayer
var _period: Label
var _indicators: HBoxContainer
var _legend: Label
var _lod_label: Label
var _tooltip: PanelContainer
var _tooltip_label: Label
var _toast: Label
var _next_btn: Button
var _overlay := Overlays.DEFS[0]
var _change_mode := false        # map shows last quarter's change of the overlay variable
var _change_btn: CheckButton
var _weighting_label: Label
var _log_panel: PanelContainer
var _log_label: Label


var ready_ticks_ms := 0  # engine start -> main screen _ready (QA timing)


func _ready() -> void:
	ready_ticks_ms = Time.get_ticks_msec()
	RenderingServer.set_default_clear_color(Color("1b2f3d"))
	map_view = MapView.new()
	add_child(map_view)
	camera = MapCamera.new()
	add_child(camera)
	camera.make_current()
	var err := map_view.load_map()
	if err != "":
		push_error(err)
	print("map loaded in %d ms (%d regions, %s)" % [map_view.load_ms, map_view.region_ids.size(), map_view.active_lod])
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
	var pend := Game.pending_case()
	if pend != "":
		_on_case_presented(pend)
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
	if args.has("map-bench"):
		var bench := QaMapBench.new()
		bench.main = self
		bench.out_dir = args["map-bench"]
		add_child(bench)
		bench.run()
		return
	if not args.has("screenshot"):
		return
	await get_tree().process_frame
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
		map_view.set_selected(args.select)
		region_panel.show_region(args.select)
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
	for _f in 8:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(args.screenshot)
	print("screenshot saved: ", args.screenshot)
	get_tree().quit()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.make_theme()
	_ui.add_child(root)

	# Top bar: national state (Level 1 · Ringkas).
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL, 0, 12))
	root.add_child(top)
	var tb := UiKit.hbox(28)
	top.add_child(tb)
	var titlebox := UiKit.vbox(0)
	titlebox.add_child(UiKit.label("NUSANTARA", 22, UiKit.ACCENT))
	titlebox.add_child(UiKit.label("Presiden Nara Adinata", 12, UiKit.MUTED))
	tb.add_child(titlebox)
	_period = UiKit.label("", 16)
	tb.add_child(_period)
	var indbox := UiKit.vbox(2)
	indbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.add_child(indbox)
	_indicators = UiKit.hbox(22)
	indbox.add_child(_indicators)
	_weighting_label = UiKit.label("", 11, UiKit.MUTED)
	indbox.add_child(_weighting_label)
	# Names exactly which starting values are still neutral defaults (none -> no warning).
	var uncal: Array = ContentDB.uncalibrated_variables()
	if not uncal.is_empty():
		var warn := UiKit.tag("%d VARIABEL AWAL BELUM TERKALIBRASI" % uncal.size(), UiKit.WARN)
		warn.tooltip_text = "Belum ada data resmi tingkat kab/kota yang diolah untuk: %s. Penduduk dan kesejahteraan (IPM) sudah memakai data BPS." % ", ".join(uncal.map(func(v): return ChangeText.var_label(str(v))))
		warn.mouse_filter = Control.MOUSE_FILTER_STOP
		tb.add_child(warn)

	# Left column: overlay selector + legend, then budget panel (stacked, never overlapping).
	var left_col := UiKit.vbox(10)
	left_col.position = Vector2(16, 86)
	root.add_child(left_col)
	var left := PanelContainer.new()
	left_col.add_child(left)
	var lb := UiKit.vbox(6)
	left.add_child(lb)
	lb.add_child(UiKit.label("Lapisan peta", 14, UiKit.MUTED))
	var group := ButtonGroup.new()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	lb.add_child(grid)
	for d in Overlays.DEFS:
		var b := Button.new()
		b.text = d.label
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = d == _overlay
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var dd: Dictionary = d
		b.pressed.connect(func(): _set_overlay(dd))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		grid.add_child(b)
	_change_btn = CheckButton.new()
	_change_btn.text = "Perubahan kuartal (C)"
	_change_btn.tooltip_text = "Warnai peta menurut perubahan variabel ini selama kuartal terakhir, bukan nilainya."
	_change_btn.toggled.connect(func(on: bool): _change_mode = on; _recolor())
	lb.add_child(_change_btn)
	_legend = UiKit.label("", 12, UiKit.MUTED, true)
	_legend.custom_minimum_size.x = 170
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lb.add_child(_legend)
	_lod_label = UiKit.label("", 11, UiKit.MUTED, true)
	_lod_label.custom_minimum_size.x = 170
	lb.add_child(_lod_label)

	# Region panel (right).
	region_panel = RegionPanel.new()
	region_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	region_panel.offset_left = -476
	region_panel.offset_top = 86
	region_panel.offset_right = -16
	region_panel.offset_bottom = -90
	root.add_child(region_panel)
	region_panel.province_view_requested.connect(_view_province)

	# Bottom controls.
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_right = -16
	bottom.offset_bottom = -16
	root.add_child(bottom)
	var bb := UiKit.hbox(10)
	bottom.add_child(bb)
	for spec in [["Catatan (L)", _toggle_log], ["Kebijakan (P)", _toggle_policy], ["Anggaran (B)", _toggle_budget], ["Simpan Cepat (F5)", _quicksave], ["Muat Cepat (F9)", _quickload]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		bb.add_child(b)
	_next_btn = Button.new()
	_next_btn.text = "Lanjut Kuartal ▶  (Spasi)"
	_next_btn.pressed.connect(_next_quarter)
	bb.add_child(_next_btn)

	# Budget panel (left, below overlays).
	budget_panel = BudgetPanel.new()
	left_col.add_child(budget_panel)

	# Case modal (centre).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	case_modal = CaseModal.new()
	center.add_child(case_modal)
	policy_panel = PolicyPanel.new()
	center.add_child(policy_panel)
	case_modal.decided.connect(_on_decided)

	# Event log (bottom left, toggled): decisions and quarter summaries from SimWorld.event_log.
	_log_panel = PanelContainer.new()
	_log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_log_panel.offset_left = 290
	_log_panel.offset_bottom = -16
	_log_panel.custom_minimum_size = Vector2(560, 0)
	var lv := UiKit.vbox(6)
	_log_panel.add_child(lv)
	lv.add_child(UiKit.label("Catatan peristiwa (terbaru di atas)", 14, UiKit.MUTED))
	var ls := ScrollContainer.new()
	ls.custom_minimum_size = Vector2(540, 220)
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(ls)
	_log_label = UiKit.label("", 12, UiKit.TEXT, true)
	_log_label.custom_minimum_size.x = 520
	ls.add_child(_log_label)
	_log_panel.visible = false
	root.add_child(_log_panel)

	# Hover tooltip + toast.
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_LIGHT, 6, 8))
	_tooltip_label = UiKit.label("", 14)
	_tooltip.add_child(_tooltip_label)
	_tooltip.visible = false
	root.add_child(_tooltip)
	_toast = UiKit.label("", 16, UiKit.ACCENT)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_top = -120
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_toast)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var wp := map_view.get_global_mouse_position()
		var id := map_view.region_at(wp)
		map_view.set_hovered(id)
		_update_tooltip(id, (event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := map_view.region_at(map_view.get_global_mouse_position())
		map_view.set_selected(id)
		region_panel.show_region(id)
		if policy_panel.visible:
			policy_panel.region_id = id
			policy_panel.refresh()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: _next_quarter()
			KEY_F5: _quicksave()
			KEY_B: _toggle_budget()
			KEY_P: _toggle_policy()
			KEY_C: _change_btn.button_pressed = not _change_btn.button_pressed
			KEY_L: _toggle_log()
			KEY_F9: _quickload()
			KEY_ESCAPE:
				map_view.set_selected("")
				region_panel.show_region("")
			KEY_S:
				if k.ctrl_pressed or k.meta_pressed:
					_manual_save()


func _update_tooltip(id: String, screen_pos: Vector2) -> void:
	if id == "" or case_modal.visible:
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
	_tooltip.position = screen_pos + Vector2(18, 18)
	_tooltip.reset_size()
	_tooltip.visible = true


func _set_overlay(d: Dictionary) -> void:
	_overlay = d
	_recolor()


func _recolor() -> void:
	var w := Game.world
	if _overlay.ramp == "categorical":
		map_view.recolor(func(id): return Overlays.ISLAND_COLORS.get(ContentDB.region_by_id[id].island_group, Color.GRAY))
		_legend.text = "Pengelompokan pulau/kawasan untuk navigasi (bukan hierarki administrasi resmi)."
		return
	var v: String = _overlay.var
	var uncal := PackedByteArray()
	uncal.resize(w.region_count())
	var n_uncal := 0
	for i in w.region_count():
		if ContentDB.region_baseline_status(v, i) == "UNCALIBRATED":
			uncal[i] = 1
			n_uncal += 1
	var hatch := "\nArsir = nilai awal belum terkalibrasi (%d wilayah): nilai netral permainan, bukan data terukur." % n_uncal if n_uncal > 0 else ""
	if _change_mode:
		var d := SimLedger.deltas(w, v)
		if d.is_empty():
			map_view.recolor(func(_id): return Overlays.change_color(0.0, 1.0))
			_legend.text = "Perubahan %s: belum ada kuartal yang disimulasikan." % _overlay.label
			return
		var scale := Overlays.change_scale(d)
		map_view.recolor(func(id):
			var i: int = w.region_index[id]
			var col := Overlays.change_color(d[i], scale)
			return Overlays.uncalibrated(col) if uncal[i] == 1 else col)
		_legend.text = "Perubahan %s, bulan ke-%d–%d: biru = turun, oranye = naik, abu-abu = tetap (skala ±%s). Warna tidak menilai baik/buruk.\nNilai SIMULASI.%s" % [
			_overlay.label, int(w.ledger.start_tick) + 1, w.tick, Fmt.num(scale, 1), hatch]
		return
	var arr: PackedFloat64Array = w.vars[v]
	map_view.recolor(func(id):
		var i: int = w.region_index[id]
		var col := Overlays.color(_overlay, arr[i])
		return Overlays.uncalibrated(col) if uncal[i] == 1 else col)
	_legend.text = "%s: %s (rendah) → %s (tinggi)\nNilai SIMULASI.%s" % [
		_overlay.label, Fmt.num(_overlay.min, 0), Fmt.num(_overlay.max, 0), hatch]


func _refresh_all() -> void:
	var w := Game.world
	_period.text = Fmt.period(w) + (" · MASA JABATAN SELESAI" if w.is_term_over() else "")
	UiKit.clear(_indicators)
	var n: Dictionary = Game.sim.national_summary(w)
	var has_q := SimLedger.active(w)
	# National indicators are aggregated from the 514 regional states; ▲▼ = change over the last quarter.
	for spec in [["Kesejahteraan", "welfare"], ["Sentimen", "sentiment"], ["Harga", "price_level"], ["Kepercayaan", "trust"], ["Lingkungan", "environment"], ["Ruang Fiskal", "fiscal_space"]]:
		var key: String = spec[1]
		var val: float = float(w.national.get("fiscal_space", 0.0)) if key == "fiscal_space" else float(n[key])
		var box := UiKit.vbox(0)
		box.add_child(UiKit.label(spec[0], 12, UiKit.MUTED))
		var row := UiKit.hbox(4)
		row.add_child(UiKit.label(Fmt.num(val, 1), 18))
		if has_q:
			var prev: float = float(w.ledger.get("fiscal_space_start", val)) if key == "fiscal_space" else w.weighted_mean_of(w.ledger.start[key])
			if absf(val - prev) >= 0.05:
				row.add_child(UiKit.label("%s %s" % ["▲" if val > prev else "▼", Fmt.num(absf(val - prev), 1)], 12, UiKit.MUTED))
		box.add_child(row)
		if key == "fiscal_space":
			box.tooltip_text = "Ruang fiskal nasional (indeks simulasi). ▲▼ = perubahan selama kuartal terakhir."
		else:
			box.tooltip_text = "Indikator nasional = %s dari kondisi simulasi tiap wilayah. ▲▼ = perubahan selama kuartal terakhir." % ChangeText.weighting_label(w.national_weighting())
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		_indicators.add_child(box)
	_weighting_label.text = "Indikator nasional: %s." % ChangeText.weighting_label(w.national_weighting())
	_next_btn.disabled = Game.pending_case() != "" or w.is_term_over()
	_recolor()
	region_panel.refresh()
	_refresh_log()


func _refresh_log() -> void:
	if not _log_panel.visible:
		return
	var parts: Array = []
	var entries: Array = Game.world.event_log
	for k in range(entries.size() - 1, maxi(-1, entries.size() - 13), -1):
		parts.append(ChangeText.entry_text(entries[k]))
	_log_label.text = "\n\n".join(parts) if not parts.is_empty() else "Belum ada peristiwa. Keputusan dan ringkasan kuartal akan muncul di sini."


func _toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible
	_refresh_log()


func _next_quarter() -> void:
	if case_modal.visible or _next_btn.disabled:
		return
	var t0 := Time.get_ticks_usec()
	Game.advance_quarter()
	var msg := "Kuartal berjalan: 3 bulan disimulasikan untuk %d wilayah (%.1f ms)" % [Game.world.region_count(), (Time.get_ticks_usec() - t0) / 1000.0]
	var entries: Array = Game.world.event_log
	if not entries.is_empty() and str(entries[-1].kind) == "quarter":
		var changed := 0
		for vrow in entries[-1].vars:
			changed = maxi(changed, int(vrow.regions_moved))
		msg += " · %d wilayah berubah · Catatan (L) · Perubahan (C)" % changed
	_toast_msg(msg)
	_refresh_all()


func _on_case_presented(id: String) -> void:
	_tooltip.visible = false
	_focus_case(id)  # the map behind the modal shows where the case happens
	case_modal.present(id)
	_refresh_all()


func _focus_case(case_id: String) -> void:
	var c: Dictionary = ContentDB.cases[case_id]
	if c.get("focus_regions", []).is_empty():
		return
	var rect := map_view.region_rect(c.focus_regions[0])
	for id in c.focus_regions:
		rect = rect.merge(map_view.region_rect(id))
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
		policy_panel.region_id = region_panel.region_id
		policy_panel.open()


func _toggle_budget() -> void:
	if budget_panel.visible:
		budget_panel.visible = false
	else:
		budget_panel.open()


func _quicksave() -> void:
	var err := Game.save_to(SaveService.QUICKSAVE_ID, "Simpan Cepat")
	_toast_msg(err if err != "" else "Tersimpan (simpan cepat).")


func _quickload() -> void:
	var err := Game.load_from(SaveService.QUICKSAVE_ID)
	_toast_msg(err if err != "" else "Simpan cepat dimuat.")


func _manual_save() -> void:
	var id := "manual_" + Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var err := Game.save_to(id, "Simpanan " + Fmt.period(Game.world))
	_toast_msg(err if err != "" else "Tersimpan sebagai slot baru.")


func _on_view_changed() -> void:
	map_view.update_view(camera.zoom.x)
	var m_per_px := MapView.KM_PER_UNIT * 1000.0 / camera.zoom.x
	var level: String = {"lod1": "Nasional", "lod2": "Kawasan/provinsi", "lod3": "Kabupaten/kota"}.get(map_view.active_lod, "?")
	_lod_label.text = "Detail peta: %s (%s) · 1 piksel ≈ %s" % [level, map_view.active_lod.to_upper(),
		("%s km" % Fmt.num(m_per_px / 1000.0, 2)) if m_per_px >= 1000.0 else ("%d m" % roundi(m_per_px))]


## Zoom to a province (the "higher administrative view" of a selected kab/kota).
func _view_province(province_id: String) -> void:
	var rect := map_view.province_rect(province_id)
	if rect.size != Vector2.ZERO:
		camera.focus_rect(rect, get_viewport().get_visible_rect().size)


func _toast_msg(msg: String) -> void:
	_toast.text = msg
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.8)
