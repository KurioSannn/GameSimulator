class_name RegionPanel
extends PanelContainer
## Level 2 (Wilayah) + Level 3 (Data Mendalam) view of one kab/kota. Read-only on SimWorld.

signal province_view_requested(province_id: String)

const SHOWN_VARS :=["welfare", "price_level", "food_supply", "infrastructure", "logistics", "services", "damage", "flood_frequency", "flood_risk_profile", "flood_protection", "environment", "trust"]

var _body: VBoxContainer
var region_id := ""


func _ready() -> void:
	custom_minimum_size = Vector2(460, 0)
	clip_contents = true
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = UiKit.vbox(6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	visible = false


func show_region(id: String) -> void:
	region_id = id
	visible = id != ""
	refresh()


func refresh() -> void:
	if region_id == "" or not is_inside_tree():
		return
	UiKit.clear(_body)
	var w: SimWorld = Game.world
	var sim: Simulation = Game.sim
	var r: Dictionary = ContentDB.region_by_id[region_id]
	var p: Dictionary = ContentDB.province_by_id.get(r.parent_region_id, {})
	var i: int = w.region_index[region_id]

	var head := UiKit.hbox()
	var title := UiKit.label(_display_name(r), 24, UiKit.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.tooltip_text = "Tutup (Esc)"
	close.pressed.connect(func(): show_region(""))
	head.add_child(close)
	_body.add_child(head)
	_body.add_child(UiKit.label("%s · Provinsi %s" % [r.kind.capitalize(), p.get("name", "?")], 13, UiKit.MUTED, true))
	# Canonical identity from the registry (ContentDB), never from map geometry (D-050).
	var codes := UiKit.label("Kode Kemendagri %s · Kode BPS %s · Provinsi %s (BPS %s)" % [
		region_id, r.get("kode_bps", "?"), r.parent_region_id, p.get("kode_bps", "?")], 12, UiKit.MUTED, true)
	codes.tooltip_text = "Kode Kemendagri adalah kunci wilayah resmi. Kode BPS hanya untuk mencocokkan data statistik; untuk enam provinsi Papua nomornya berbeda dari Kemendagri."
	codes.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.add_child(codes)
	var nav := UiKit.hbox(8)
	var up := Button.new()
	up.text = "Lihat Provinsi %s" % p.get("name", "")
	up.pressed.connect(func(): province_view_requested.emit(r.parent_region_id))
	nav.add_child(up)
	_body.add_child(nav)

	# Sentiment block with explanation of drivers.
	var s := w.get_v("sentiment", i)
	var st := sim.sentiment_state(s)
	var srow := UiKit.hbox()
	srow.add_child(UiKit.label("Sentimen publik:", 16))
	srow.add_child(UiKit.label("%s (%s)" % [st.label, Fmt.num(s, 0)], 16, UiKit.ACCENT))
	_body.add_child(srow)
	_body.add_child(UiKit.label(explain_sentiment(sim.sentiment_components(w, i)), 13, UiKit.MUTED, true))
	_body.add_child(UiKit.tag("SIMULASI", UiKit.SIM))
	_body.add_child(HSeparator.new())
	_add_changes(w, i)
	_add_scheduled(w, i)
	_add_national_drivers(w)

	# Real reference facts.
	_body.add_child(UiKit.label("Data acuan", 15, UiKit.TEXT))
	var insts: Dictionary = ContentDB.source_institutions
	for f in r.get("facts", []):
		var row := HFlowContainer.new()  # long source tags wrap below the value instead of widening the panel
		row.add_theme_constant_override("h_separation", 8)
		row.add_child(UiKit.label("%s: %s" % [f.label, Fmt.unit_value(float(f.value), str(f.unit))], 14))
		row.add_child(UiKit.tag("NYATA · %s %s" % [Fmt.short_institution(str(insts.get(f.source_id, f.source_id))), f.period], UiKit.REAL))
		_body.add_child(row)
	if r.get("ibukota"):
		_body.add_child(UiKit.label("Pusat pemerintahan: %s" % r.ibukota, 14))
	_body.add_child(HSeparator.new())

	# Simulated state.
	_body.add_child(UiKit.label("Kondisi simulasi", 15))
	for v in SHOWN_VARS:
		var spec: Dictionary = sim.bounds[v]
		var row := UiKit.hbox()
		var name := UiKit.label(str(spec.label), 14, UiKit.MUTED)
		name.custom_minimum_size.x = 150
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long labels wrap instead of widening the panel
		row.add_child(name)
		var val := w.get_v(v, i)
		if v == "fire_prevention" and val == 0.0 and Game.session.initial_vars.get(v, PackedFloat64Array([0.0]))[i] == 0.0:
			continue  # only where fire prevention has been built
		var dec := 2 if spec.unit == "rasio" else 1
		var vl := UiKit.label(Fmt.num(val, dec), 14)
		vl.custom_minimum_size.x = 44
		row.add_child(vl)
		var init: PackedFloat64Array = Game.session.initial_vars.get(v, PackedFloat64Array())
		if not init.is_empty():
			var d := val - init[i]
			var dl := UiKit.label("awal %s%s" % [Fmt.num(init[i], dec), (" (%s)" % Fmt.signed(d, dec)) if absf(d) >= 0.05 else ""], 12, UiKit.MUTED)
			dl.tooltip_text = "Nilai pada awal masa jabatan dan selisihnya sampai sekarang (hasil simulasi)."
			dl.mouse_filter = Control.MOUSE_FILTER_STOP
			dl.custom_minimum_size.x = 84
			row.add_child(dl)
		var rs := ContentDB.region_baseline_status(v, i)
		if rs == "UNCALIBRATED":
			var tg := UiKit.tag("BLM KALIBRASI", UiKit.WARN)
			tg.tooltip_text = "Nilai awal netral permainan, bukan statistik resmi."
			tg.mouse_filter = Control.MOUSE_FILTER_STOP
			row.add_child(tg)
		elif rs == "BY_DESIGN":
			var tg := UiKit.tag("NILAI MODEL", UiKit.SIM)
			tg.tooltip_text = "Keadaan model, bukan data statistik: %s" % str(ContentDB.baseline.variables[v].provenance.get("reason", ""))
			tg.mouse_filter = Control.MOUSE_FILTER_STOP
			row.add_child(tg)
		elif rs == "PROVINCE_PROXY":
			row.add_child(UiKit.tag("AWAL: PROKSI PROVINSI", UiKit.WARN))
		else:
			var tg := UiKit.tag("AWAL: DATA %s" % str(ContentDB.baseline.variables[v].reference_period), UiKit.REAL)
			tg.tooltip_text = "Nilai awal diturunkan dari data resmi: %s" % ", ".join(ContentDB.baseline.variables[v].provenance.sources)
			tg.mouse_filter = Control.MOUSE_FILTER_STOP
			row.add_child(tg)
		_body.add_child(row)
	if SHOWN_VARS.any(func(sv): return ContentDB.region_baseline_status(sv, i) == "UNCALIBRATED"):
		_body.add_child(UiKit.label("Nilai awal bertanda \"belum terkalibrasi\" adalah nilai netral permainan karena data resmi tingkat kabupaten/kota belum tersedia di proyek; bukan statistik resmi.", 12, UiKit.MUTED, true))
	_body.add_child(UiKit.label("\"Nilai model\" = keadaan yang didefinisikan oleh simulasi (misalnya kerusakan 0 di awal masa jabatan), bukan pengukuran.", 12, UiKit.MUTED, true))


## "Apa yang berubah dan mengapa": last simulated quarter from the SimLedger, causes largest first.
## The causes listed sum to the change shown (exact attribution, tested).
func _add_changes(w: SimWorld, i: int) -> void:
	_body.add_child(UiKit.label("Perubahan kuartal terakhir", 15))
	if not SimLedger.active(w):
		_body.add_child(UiKit.label("Belum ada kuartal yang disimulasikan. Ambil keputusan lalu lanjutkan kuartal.", 13, UiKit.MUTED, true))
		_body.add_child(HSeparator.new())
		return
	_body.add_child(UiKit.label("Bulan ke-%d–%d" % [int(w.ledger.start_tick) + 1, w.tick], 12, UiKit.MUTED))
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
			var cl := UiKit.label("   %s %s" % [Fmt.signed(c.delta, dec), ChangeText.cause_label(str(c.cause))], 12,
				UiKit.ACCENT if str(c.cause).begins_with("eff:") else UiKit.MUTED, true)
			_body.add_child(cl)
	if shown == 0:
		_body.add_child(UiKit.label("Tidak ada perubahan berarti di wilayah ini pada kuartal terakhir.", 13, UiKit.MUTED, true))
	_body.add_child(UiKit.label("Penyebab = selisih yang benar-benar dihitung tiap langkah simulasi; \"(model)\" = dinamika model, koefisien rancangan belum terkalibrasi.", 11, UiKit.MUTED, true))
	_body.add_child(HSeparator.new())


## Effects already decided that will still reach this region (delayed or ongoing).
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
	_body.add_child(UiKit.label("Efek terjadwal", 15))
	for l in lines.slice(0, 6):
		_body.add_child(UiKit.label(l, 12, UiKit.TEXT, true))
	if lines.size() > 6:
		_body.add_child(UiKit.label("… dan %d efek lainnya" % (lines.size() - 6), 12, UiKit.MUTED))
	_body.add_child(HSeparator.new())


## National price pressure moves every region's price target; show its size, its sources (SimLedger
## drivers) and scheduled national changes, so a regional price rise can be traced to its national cause.
func _add_national_drivers(w: SimWorld) -> void:
	var pp := float(w.national.get("price_pressure", 0.0))
	var pending: Array = []
	for e in w.pending_effects:
		if e.scope == "national" and str(e.var) in SimLedger.DRIVEN:
			pending.append({"var": e.var, "op": e.op, "value": e.value, "scope": "national", "regions": -1,
				"delay_months": int(e.apply_tick) - w.tick, "duration": int(e.remaining), "source": e.source})
	if absf(pp) < 0.0005 and pending.is_empty():
		return
	_body.add_child(UiKit.label("Faktor nasional", 15))
	if absf(pp) >= 0.0005:
		_body.add_child(UiKit.label("Tekanan harga nasional saat ini %s pada harga sasaran semua wilayah." % ChangeText.national_value("price_pressure", pp, true), 13, UiKit.TEXT, true))
		var fr := SimLedger.driver_fractions(w, "price_pressure", pp)
		var keys := fr.keys()
		keys.sort_custom(func(a, b): return absf(fr[a]) > absf(fr[b]))
		for k in keys.slice(0, 4):
			var origin := "sumber tidak tercatat (simpanan lama)" if k == SimLedger.UNRECORDED else ChangeText.source_label(str(k))
			_body.add_child(UiKit.label("   %s %s" % [ChangeText.national_value("price_pressure", pp * float(fr[k]), true), origin], 12, UiKit.ACCENT, true))
	for e in pending:
		_body.add_child(UiKit.label("• Terjadwal: %s — %s" % [ChangeText.source_label(str(e.source)), ChangeText.effect_line(e)], 12, UiKit.TEXT, true))
	_body.add_child(UiKit.label("Bobot minyak goreng dalam indeks harga dan ketergantungan sawit per provinsi belum dimodelkan: tekanan ini nilai desain, bukan statistik resmi.", 11, UiKit.MUTED, true))
	_body.add_child(HSeparator.new())


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
