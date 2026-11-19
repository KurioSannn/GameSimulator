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


func _ready() -> void:
	custom_minimum_size = Vector2(476, 0)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StitchTheme.soft_box(Color("0d1b3f", 0.96), Color(1, 1, 1, 0.16), 12, 16, 14, 1))
	var root := UiKit.vbox(10)
	add_child(root)

	var header := PanelContainer.new()
	header.theme_type_variation = "PanelHeader"
	var row := UiKit.hbox(8)
	var title := UiKit.title("DETAIL WILAYAH", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var close := UiKit.ghost_button("×", func(): show_region(""), "Tutup panel wilayah (Esc)")
	close.custom_minimum_size = Vector2(36, 34)
	row.add_child(close)
	header.add_child(row)
	root.add_child(header)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	_body = UiKit.vbox(10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	root.add_child(HSeparator.new())
	var foot := UiKit.hbox(10)
	var data := UiKit.ghost_button("DATA DAN SUMBER", func(): sources_requested.emit(_model), "Lihat data resmi & sumber")
	data.custom_minimum_size.y = 42
	data.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(data)
	var policy := UiKit.button("ATUR KEBIJAKAN", func(): policy_requested.emit(context_kind, context_id), true)
	policy.custom_minimum_size.y = 42
	policy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var w: SimWorld = Game.world
	_model = RegionViewModel.build(w, context_kind, context_id, ContentDB.regions, ContentDB.provinces,
		ContentDB.baseline, ContentDB.cases, ContentDB.policies)

	var title := UiKit.title(str(_model.name), 28, UiKit.ACCENT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(title)
	_body.add_child(UiKit.label(str(_model.resolution), 13, UiKit.MUTED, true))

	if not _model.valid:
		_body.add_child(UiKit.label("Data wilayah tidak ditemukan. Pilih kembali dari peta.", 15, UiKit.WARN, true))
		return

	var record: Dictionary = _model.record
	if context_kind == "kabkota":
		var parent: Dictionary = ContentDB.province_by_id.get(str(record.get("parent_region_id", "")), {})
		var parent_id := str(parent.get("region_id", ""))
		var pbtn := UiKit.ghost_button("Lihat Provinsi " + str(parent.get("name", "")),
			func(): province_view_requested.emit(parent_id); show_context("province", parent_id),
			"Pusatkan peta ke seluruh provinsi induk")
		pbtn.custom_minimum_size.y = 34
		pbtn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_body.add_child(pbtn)

	if context_kind in ["kabkota", "province"]:
		_body.add_child(UiKit.label("Kode Kemendagri %s · Kode BPS %s" % [context_id, record.get("kode_bps", "Belum tercatat")], 12, UiKit.MUTED, true))

	var weighting := "Wilayah tunggal" if context_kind == "kabkota" else ("Bobot penduduk" if _model.weighting == "population" else "Setara 514 wilayah")
	var cond_sec := UiKit.section_bar("KONDISI WILAYAH", weighting, UiKit.ACCENT)
	cond_sec.tooltip_text = "Nilai permainan (bukan statistik resmi). Harga 100 = awal mandat; ± = perubahan kuartal terakhir. " + ChangeText.weighting_label(_model.weighting)
	cond_sec.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.add_child(cond_sec)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for metric in _model.metrics:
		grid.add_child(_metric_card(metric))
	_body.add_child(grid)

	_add_summary("PERISTIWA AKTIF", int(_model.cases.size()), "Belum ada kasus aktif di wilayah ini.",
		_model.cases.map(func(c): return str(c.title)))
	if not _model.cases.is_empty():
		var cid: String = _model.cases[0].id
		var open_btn := UiKit.button("BUKA KEPUTUSAN", func(): case_requested.emit(cid), true)
		open_btn.custom_minimum_size.y = 40
		_body.add_child(open_btn)

	var fact_lines: Array = []
	for fact in _model.facts:
		if str(fact.id) in ["pop_total", "ipm"]:
			fact_lines.append("%s: %s (%s)" % [fact.label, Fmt.unit_value(float(fact.value), str(fact.unit)), fact.period])
	_add_summary("DATA RESMI WILAYAH", int(_model.facts.size()), "Data resmi tingkat ini belum tersedia.", fact_lines)

	var policy_lines: Array = []
	for policy in _model.policies:
		policy_lines.append("%s (%s)" % [policy.name, "Sedang dibangun" if policy.status == "implementing" else "Aktif"])
	_add_summary("KEBIJAKAN BERJALAN", int(_model.policies.size()),
		"Belum ada kebijakan khusus untuk wilayah ini.", policy_lines)

	if "UNCALIBRATED" in _model.baseline_flags:
		var u_tag := UiKit.tag("ⓘ Mode simulasi: sebagian data awal netral · cek Sumber", UiKit.INFO, 11)
		u_tag.tooltip_text = "Buka Data dan Sumber di bawah untuk melihat rincian data awal & referensi resmi."
		u_tag.mouse_filter = Control.MOUSE_FILTER_STOP
		_body.add_child(u_tag)

	if context_kind == "kabkota":
		var detail := UiKit.vbox(8)
		detail.hide()
		var toggle_btn := UiKit.ghost_button("LIHAT RINCIAN & PENYEBAB ▾", func(): detail.visible = not detail.visible)
		toggle_btn.custom_minimum_size.y = 38
		_body.add_child(toggle_btn)
		_body.add_child(detail)
		var summary_body := _body
		_body = detail
		var i: int = w.region_index[context_id]
		var sentiment := Game.sim.sentiment_state(w.get_v("sentiment", i))
		_body.add_child(UiKit.title("Sentimen Warga: " + str(sentiment.label), 17, UiKit.ACCENT))
		_body.add_child(UiKit.label(explain_sentiment(Game.sim.sentiment_components(w, i)), 14, UiKit.TEXT, true))
		_add_changes(w, i)
		_add_scheduled(w, i)
		_add_national_drivers(w)
		_add_full_state(w, i)
		_body = summary_body


func _metric_card(metric: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "PanelCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := UiKit.vbox(3)
	panel.add_child(body)
	body.add_child(UiKit.subheader(str(metric.label), UiKit.MUTED, 10))
	var row := UiKit.hbox(4)
	var value := "—" if metric.value == null else Fmt.num(float(metric.value), 1)
	row.add_child(UiKit.title(value, 21))
	row.add_child(UiKit.spacer())
	if metric.delta == null:
		row.add_child(UiKit.label("—", 12, UiKit.MUTED))
	else:
		var dv := float(metric.delta)
		var is_price := str(metric.key) == "price_level"
		var dcol := UiKit.MUTED
		if absf(dv) >= 0.05:
			var good := dv < 0.0 if is_price else dv > 0.0
			dcol = UiKit.SUCCESS if good else UiKit.DANGER
		row.add_child(UiKit.label(Fmt.signed(dv, 1), 12, dcol))
	body.add_child(row)
	var unit_short := str(metric.unit).replace("skala ", "").replace("indeks model", "indeks").replace("persen", "%")
	body.add_child(UiKit.label(unit_short, 11, UiKit.MUTED))
	panel.tooltip_text = "Sumber awal: " + ", ".join(metric.baseline_flags)
	return panel


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
