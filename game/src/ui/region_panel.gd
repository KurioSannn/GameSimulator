class_name RegionPanel
extends PanelContainer
## Clean, scannable regional detail drawer for kab/kota, provinces, island groups and national contexts.

signal province_view_requested(province_id: String)
signal sources_requested(model: Dictionary)
signal policy_requested(kind: String, id: String)
signal case_requested(case_id: String)

const SHOWN_VARS := ["welfare", "price_level", "food_supply", "infrastructure", "logistics", "services", "damage", "flood_frequency", "flood_risk_profile", "flood_protection", "environment", "trust"]
var _body: VBoxContainer
var _scroll: ScrollContainer
var _model: Dictionary = {}
var region_id := ""
var context_kind := "kabkota"
var context_id := ""
var _tab := "kondisi"
var _tab_buttons: Dictionary = {}
var _details_open := false
var _heading: Label
var _source_button: Button
var _root: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(430, 0)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", GameSkin.frame())
	var root := UiKit.vbox(10)
	_root = root
	add_child(root)

	var header := PanelContainer.new()
	header.theme_type_variation = "PanelHeader"
	var row := UiKit.hbox(8)
	var title := UiKit.title("Wilayah", 28, Color("fff4d2"))
	_heading = title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var close := UiKit.ghost_button("×", func(): show_region(""), "Tutup panel wilayah (Esc)")
	close.custom_minimum_size = Vector2(36, 34)
	row.add_child(close)
	header.add_child(row)
	root.add_child(header)
	var tabs := UiKit.hbox(6)
	for item in [["Kondisi", "kondisi"], ["Aktivitas", "aktivitas"], ["Data", "data"]]:
		var id: String = item[1]
		var tab := UiKit.ghost_button(item[0], func(): _tab = id; _scroll.scroll_vertical = 0; refresh())
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab)
		_tab_buttons[id] = tab
	root.add_child(tabs)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	_body = UiKit.vbox(10)
	_body.minimum_size_changed.connect(func(): if visible: _fit_body.call_deferred())
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	root.add_child(HSeparator.new())
	var foot := UiKit.hbox(10)
	var data := UiKit.ghost_button("Sumber", func(): sources_requested.emit(_model), "Lihat data resmi & sumber")
	_source_button = data
	data.custom_minimum_size.y = 42
	data.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(data)
	var policy := UiKit.button("Kebijakan", func(): policy_requested.emit(context_kind, context_id))
	policy.custom_minimum_size.y = 42
	policy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	policy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(policy)
	root.add_child(foot)
	hide()


func show_region(id: String) -> void:
	if id == "":
		region_id = ""
		context_id = ""
		_model = {}
		var vp := get_viewport()
		var fo := vp.gui_get_focus_owner() if vp != null else null
		if fo != null and (fo == self or is_ancestor_of(fo)):
			fo.release_focus()
		hide()
		return
	show_context("kabkota", id)


func show_context(kind: String, id: String) -> void:
	if kind != context_kind or id != context_id:
		_tab = "kondisi"
		_details_open = false
	context_kind = kind
	context_id = id
	region_id = id if kind == "kabkota" else ""
	_scroll.scroll_vertical = 0
	var was_hidden := not visible
	refresh()
	show()
	if was_hidden:
		UiKit.animate_open(self)


func refresh() -> void:
	if context_id == "" or not is_inside_tree():
		return
	UiKit.clear(_body)
	var world: SimWorld = Game.world
	_model = RegionViewModel.build(world, context_kind, context_id, ContentDB.regions, ContentDB.provinces,
		ContentDB.baseline, ContentDB.cases, ContentDB.policies)
	for id in _tab_buttons:
		_tab_buttons[id].theme_type_variation = "ButtonAccent" if id == _tab else "ButtonGhost"
	_heading.text = str(_model.name)
	_source_button.visible = _tab == "data"
	if not _model.valid:
		_body.add_child(UiKit.label("Data wilayah tidak ditemukan. Pilih kembali dari peta.", 16, UiKit.WARN, true))
		return
	if context_kind == "kabkota" and _tab == "data":
		var record: Dictionary = _model.record
		var parent: Dictionary = ContentDB.province_by_id.get(str(record.get("parent_region_id", "")), {})
		var parent_id := str(parent.get("region_id", ""))
		var parent_button := UiKit.ghost_button("↗ " + str(parent.get("name", "")),
			func(): province_view_requested.emit(parent_id); show_context("province", parent_id),
			"Lihat provinsi induk")
		parent_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_body.add_child(parent_button)
	match _tab:
		"aktivitas":
			_show_activity()
		"data":
			_show_official_data()
		_:
			_show_conditions(world)
	_fit_body.call_deferred()


func _fit_body() -> void:
	if not visible:
		return
	var reserved := get_theme_stylebox("panel").get_minimum_size().y
	var count := 0
	for child in _root.get_children():
		if child is Control and child.visible:
			count += 1
			if child != _scroll:
				reserved += child.get_combined_minimum_size().y
	reserved += _root.get_theme_constant("separation") * maxi(0, count - 1)
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, maxf(100, get_viewport_rect().size.y - 224 - reserved))
	reset_size()


func _show_conditions(world: SimWorld) -> void:
	var group := PanelContainer.new()
	group.theme_type_variation = "PanelCard"
	var rows := UiKit.vbox(7)
	group.add_child(rows)
	for metric in _model.metrics:
		if str(metric.key) in ["welfare", "trust"]:
			rows.add_child(_metric_card(metric))
	_body.add_child(group)


func _show_explanations(world: SimWorld) -> void:
	if context_kind != "kabkota":
		return
	var toggle := UiKit.ghost_button("Sembunyikan rincian  ▴" if _details_open else "Rincian & penyebab  ▾",
		func(): _details_open = not _details_open; refresh())
	_body.add_child(toggle)
	if _details_open:
		var index: int = world.region_index[context_id]
		var sentiment := Game.sim.sentiment_state(world.get_v("sentiment", index))
		_body.add_child(UiKit.title("Sentimen warga: " + str(sentiment.label), 18))
		_body.add_child(UiKit.label(explain_sentiment(Game.sim.sentiment_components(world, index)), 16, UiKit.TEXT, true))
		_add_changes(world, index)
		_add_scheduled(world, index)
		_add_national_drivers(world)
		_add_full_state(world, index)


func _show_activity() -> void:
	if _model.cases.is_empty() and _model.policies.is_empty():
		_body.add_child(UiKit.label("Belum ada peristiwa atau kebijakan aktif di wilayah ini.", 16, UiKit.MUTED, true))
	for current in _model.cases:
		var id: String = current.id
		var open := UiKit.button(str(current.title), func(): case_requested.emit(id))
		open.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(open)
	if not _model.policies.is_empty():
		_body.add_child(UiKit.title("Kebijakan berjalan", 18))
	for policy in _model.policies:
		_body.add_child(UiKit.label("%s · %s" % [policy.name, "Sedang dibangun" if policy.status == "implementing" else "Aktif"], 16, UiKit.TEXT, true))


func _show_official_data() -> void:
	_body.add_child(UiKit.title("Indikator lengkap", 24))
	for metric in _model.metrics:
		_body.add_child(_metric_card(metric))
	var record: Dictionary = _model.record
	if context_kind in ["kabkota", "province"]:
		_body.add_child(UiKit.label("Kemendagri %s · BPS %s" % [context_id, record.get("kode_bps", "Belum tercatat")], 14, UiKit.MUTED, true))
	_body.add_child(UiKit.title("Data resmi wilayah", 18, UiKit.REAL))
	if _model.facts.is_empty():
		_body.add_child(UiKit.label("Data resmi pada resolusi ini belum tersedia.", 16, UiKit.MUTED, true))
	for fact in _model.facts:
		_body.add_child(UiKit.label("%s: %s (%s)" % [fact.label, Fmt.unit_value(float(fact.value), str(fact.unit)), fact.period], 16, UiKit.TEXT, true))
	_body.add_child(UiKit.label("Buka Data dan Sumber untuk institusi, periode, resolusi, dan asal setiap nilai.", 14, UiKit.MUTED, true))
	_show_explanations(Game.world)


func _metric_card(metric: Dictionary) -> Control:
	var row := UiKit.hbox(8)
	var name_label := UiKit.label(str(metric.label).capitalize(), 14, UiKit.MUTED, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := "—" if metric.value == null else Fmt.num(float(metric.value), 1)
	var unit := "/ 100" if str(metric.unit).begins_with("skala ") else str(metric.unit).replace("indeks model", "indeks").replace("persen", "%")
	row.add_child(UiKit.number(value + " " + unit, 20))
	if metric.delta != null and absf(float(metric.delta)) >= 0.05:
		var delta := float(metric.delta)
		var good := delta < 0.0 if str(metric.key) == "price_level" else delta > 0.0
		row.add_child(UiKit.label(Fmt.signed(delta, 1), 14, UiKit.SUCCESS if good else UiKit.DANGER))
	row.tooltip_text = "Satuan: " + str(metric.unit) + ". Sumber awal: " + ", ".join(metric.baseline_flags) + ". Perubahan dari kuartal terakhir."
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	return row


func _add_summary(title: String, count: int, empty: String, lines: Array) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "PanelCard"
	var body := UiKit.vbox(4)
	panel.add_child(body)
	var head := UiKit.hbox(6)
	var tl := UiKit.title(title, 15)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	head.add_child(UiKit.tag(str(count), UiKit.ACCENT if count > 0 else UiKit.MUTED, 11))
	body.add_child(head)
	if lines.is_empty():
		body.add_child(UiKit.label(empty, 13, UiKit.MUTED, true))
	else:
		for line in lines.slice(0, 3):
			body.add_child(UiKit.label("• " + str(line), 13, UiKit.TEXT, true))
		if lines.size() > 3:
			body.add_child(UiKit.label("… dan %d lainnya" % (lines.size() - 3), 12, UiKit.MUTED))
	_body.add_child(panel)


func _add_full_state(w: SimWorld, i: int) -> void:
	var sim: Simulation = Game.sim
	_body.add_child(UiKit.section_bar("KONDISI SIMULASI LENGKAP", "", UiKit.TEXT))
	for v in SHOWN_VARS:
		var spec: Dictionary = sim.bounds[v]
		var val := w.get_v(v, i)
		if v == "fire_prevention" and val == 0.0 and Game.session.initial_vars.get(v, PackedFloat64Array([0.0]))[i] == 0.0:
			continue
		var card := PanelContainer.new()
		card.theme_type_variation = "PanelCard"
		var box := UiKit.vbox(4)
		card.add_child(box)

		var top := UiKit.hbox(8)
		var name := UiKit.label(str(spec.label), 13, UiKit.TEXT, true)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name)
		var dec := 2 if spec.unit == "rasio" else 1
		top.add_child(UiKit.title(Fmt.num(val, dec), 16, UiKit.ACCENT))
		box.add_child(top)

		var bot := UiKit.hbox(8)
		var init: PackedFloat64Array = Game.session.initial_vars.get(v, PackedFloat64Array())
		if not init.is_empty():
			var d := val - init[i]
			var dl := UiKit.label("Awal: %s%s" % [Fmt.num(init[i], dec), (" (%s)" % Fmt.signed(d, dec)) if absf(d) >= 0.05 else ""], 11, UiKit.MUTED)
			dl.tooltip_text = "Nilai pada awal masa jabatan dan selisihnya sampai sekarang (hasil simulasi)."
			dl.mouse_filter = Control.MOUSE_FILTER_STOP
			dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bot.add_child(dl)
		var rs := ContentDB.region_baseline_status(v, i)
		if rs == "UNCALIBRATED":
			var tg := UiKit.tag("BLM KALIBRASI", UiKit.WARN, 10)
			tg.tooltip_text = "Nilai awal netral permainan, bukan statistik resmi."
			tg.mouse_filter = Control.MOUSE_FILTER_STOP
			bot.add_child(tg)
		elif rs == "BY_DESIGN":
			var tg := UiKit.tag("NILAI MODEL", UiKit.SIM, 10)
			tg.tooltip_text = "Keadaan model, bukan data statistik: %s" % str(ContentDB.baseline.variables[v].provenance.get("reason", ""))
			tg.mouse_filter = Control.MOUSE_FILTER_STOP
			bot.add_child(tg)
		elif rs == "PROVINCE_PROXY":
			bot.add_child(UiKit.tag("PROKSI PROVINSI", UiKit.WARN, 10))
		else:
			var tg := UiKit.tag("DATA %s" % str(ContentDB.baseline.variables[v].reference_period), UiKit.REAL, 10)
			tg.tooltip_text = "Nilai awal diturunkan dari data resmi: %s" % ", ".join(ContentDB.baseline.variables[v].provenance.sources)
			tg.mouse_filter = Control.MOUSE_FILTER_STOP
			bot.add_child(tg)
		box.add_child(bot)
		_body.add_child(card)

	if SHOWN_VARS.any(func(sv): return ContentDB.region_baseline_status(sv, i) == "UNCALIBRATED"):
		_body.add_child(UiKit.label("Catatan: label «BLM KALIBRASI» adalah nilai awal netral permainan karena data kab/kota belum tersedia.", 12, UiKit.MUTED, true))


## "Apa yang berubah dan mengapa": last simulated quarter from the SimLedger, causes largest first.
func _add_changes(w: SimWorld, i: int) -> void:
	var chg_sec := UiKit.section_bar("PERUBAHAN KUARTAL TERAKHIR", "Sumber perubahan", UiKit.ACCENT)
	chg_sec.tooltip_text = "Selisih tiap langkah simulasi; \"(model)\" menandai perhitungan koefisien permainan."
	chg_sec.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.add_child(chg_sec)
	if not SimLedger.active(w):
		_body.add_child(UiKit.label("Belum ada kuartal selesai. Lanjutkan kuartal untuk melihat perubahan.", 13, UiKit.MUTED, true))
		return
	_body.add_child(UiKit.subheader("BULAN %d–%d" % [int(w.ledger.start_tick) + 1, w.tick], UiKit.MUTED, 11))
	var rows := SimLedger.region_changes(w, i)
	var shown := 0
	for r in rows:
		if absf(float(r.delta)) < 0.05 or shown >= 6:
			continue
		shown += 1
		var spec: Dictionary = Game.sim.bounds[r.var]
		var dec := 2 if spec.unit == "rasio" else 1
		_body.add_child(UiKit.label("%s: %s → %s (%s)" % [spec.label, Fmt.num(r.start, dec), Fmt.num(r.now, dec), Fmt.signed(r.delta, dec)], 14))
		for c in (r.causes as Array).slice(0, 3):
			var cl := UiKit.label("   %s %s" % [Fmt.signed(c.delta, dec), ChangeText.cause_label(str(c.cause)).replace(" (model bahaya)", "").replace(" (model)", "")], 12,
				UiKit.ACCENT if str(c.cause).begins_with("eff:") else UiKit.MUTED, true)
			_body.add_child(cl)
	if shown == 0:
		_body.add_child(UiKit.label("Tidak ada perubahan besar di wilayah ini pada kuartal terakhir.", 13, UiKit.MUTED, true))


func _add_scheduled(w: SimWorld, i: int) -> void:
	var lines: Array = []
	for e in w.pending_effects:
		if e.scope == "national" or not (i in EffectQueue.resolve_scope(w, e.scope)):
			continue
		var eff := {"var": e.var, "op": e.op, "value": e.value, "scope": "region:" + w.region_ids[i], "regions": 1,
			"delay_months": int(e.apply_tick) - w.tick, "duration": int(e.remaining)}
		lines.append("• %s — %s" % [ChangeText.source_label(str(e.source)), ChangeText.effect_line(eff).split(" · ")[0]
			+ (" · dalam %d bulan" % (int(e.apply_tick) - w.tick) if int(e.apply_tick) > w.tick else " · bulan berikutnya")
			+ (" · %d bulan" % int(e.remaining) if int(e.remaining) > 1 else "")])
	if lines.is_empty():
		return
	_body.add_child(UiKit.section_bar("EFEK TERJADWAL", "", UiKit.TEXT))
	for l in lines.slice(0, 6):
		_body.add_child(UiKit.label(l, 12, UiKit.TEXT, true))
	if lines.size() > 6:
		_body.add_child(UiKit.label("… dan %d efek lainnya" % (lines.size() - 6), 11, UiKit.MUTED))


func _add_national_drivers(w: SimWorld) -> void:
	var pp := float(w.national.get("price_pressure", 0.0))
	var pending: Array = []
	for e in w.pending_effects:
		if e.scope == "national" and str(e.var) in SimLedger.DRIVEN:
			pending.append({"var": e.var, "op": e.op, "value": e.value, "scope": "national", "regions": -1,
				"delay_months": int(e.apply_tick) - w.tick, "duration": int(e.remaining), "source": e.source})
	if absf(pp) < 0.0005 and pending.is_empty():
		return
	_body.add_child(UiKit.section_bar("FAKTOR NASIONAL", "", UiKit.TEXT))
	if absf(pp) >= 0.0005:
		_body.add_child(UiKit.label("Tekanan harga nasional saat ini %s pada harga sasaran semua wilayah." % ChangeText.national_value("price_pressure", pp, true), 12, UiKit.TEXT, true))
		var fr := SimLedger.driver_fractions(w, "price_pressure", pp)
		var keys := fr.keys()
		keys.sort_custom(func(a, b): return absf(fr[a]) > absf(fr[b]))
		for k in keys.slice(0, 4):
			var origin := "sumber tidak tercatat (simpanan lama)" if k == SimLedger.UNRECORDED else ChangeText.source_label(str(k))
			_body.add_child(UiKit.label("   %s %s" % [ChangeText.national_value("price_pressure", pp * float(fr[k]), true), origin], 11, UiKit.ACCENT, true))
	for e in pending:
		_body.add_child(UiKit.label("• Terjadwal: %s — %s" % [ChangeText.source_label(str(e.source)), ChangeText.effect_line(e)], 12, UiKit.TEXT, true))
	_body.add_child(UiKit.label("Bobot minyak goreng dalam indeks harga dan ketergantungan sawit per provinsi belum dimodelkan.", 11, UiKit.MUTED, true))


## "Sentimen tertekan terutama oleh harga dan kerusakan; ditopang oleh kepercayaan."
static func explain_sentiment(comps: Dictionary) -> String:
	var neg: Array = []
	var pos: Array = []
	for k in comps:
		if comps[k] <= -1.0:
			neg.append(k)
		elif comps[k] >= 1.0:
			pos.append(k)
	neg.sort_custom(func(a, b): return comps[a] < comps[b])
	pos.sort_custom(func(a, b): return comps[a] > comps[b])
	if neg.is_empty() and pos.is_empty():
		return "Tidak ada pendorong sentimen yang menonjol; kondisi mendekati garis dasar."
	var out := ""
	if not neg.is_empty():
		out += "Tertekan terutama oleh " + " dan ".join(neg.slice(0, 2)) + " (%s poin)." % Fmt.num(neg.slice(0, 2).reduce(func(a, k): return a + comps[k], 0.0), 0)
	if not pos.is_empty():
		out += (" " if out != "" else "") + "Ditopang oleh " + " dan ".join(pos.slice(0, 2)) + " (+%s poin)." % Fmt.num(pos.slice(0, 2).reduce(func(a, k): return a + comps[k], 0.0), 0)
	return out


static func _display_name(r: Dictionary) -> String:
	var n: String = r.name
	if r.kind == "kabupaten" and not n.begins_with("Kab"):
		return "Kabupaten " + n
	return n
