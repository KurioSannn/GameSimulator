class_name ChangeText
extends RefCounted
## Bahasa Indonesia wording for SimLedger causes and event-log entries. Pure formatting: every number
## shown here is read from the ledger/log, which record the deltas the simulation actually applied.

const SYSTEM_LABELS := {
	"sys:budget": "Anggaran sektor (model)",
	"sys:floods": "Banjir baru (model bahaya)",
	"sys:recovery": "Pemulihan dan logistik (model)",
	"sys:food_prices": "Pasokan pangan dan harga (model)",
	"sys:welfare": "Penyesuaian kesejahteraan (model)",
	"sys:sentiment": "Penyesuaian sentimen dan kepercayaan (model)",
	"sys:pp_decay": "Tekanan harga mereda (model)",
}
const TIMING_LABELS := {"now": "efek segera", "delayed": "efek tertunda", "ongoing": "efek berlanjut"}
## National scalars (not in sim_params.variables).
const NATIONAL_LABELS := {"fiscal_space": "Ruang fiskal", "price_pressure": "Tekanan harga nasional"}
const MONTHS := ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September",
	"Oktober", "November", "Desember"]


static func var_label(v: String) -> String:
	if NATIONAL_LABELS.has(v):
		return NATIONAL_LABELS[v]
	return str(ContentDB.sim_params.get("variables", {}).get(v, {}).get("label", v))


## National value as shown to the player: price pressure is a share of every region's price target.
static func national_value(key: String, v: float, signed := false) -> String:
	if key == "price_pressure":
		return (Fmt.signed(v * 100.0, 1) if signed else Fmt.num(v * 100.0, 1)) + "%"
	return Fmt.signed(v, 1) if signed else Fmt.num(v, 1)


## "sys:floods" -> "Banjir baru (model bahaya)"; "eff:case:CASE-0001/choice:a#now" ->
## "Keputusan «…»: <pilihan> (efek segera)"; "drv:price_pressure|<source>" -> the source's share of
## the national price pressure.
static func cause_label(key: String) -> String:
	if SYSTEM_LABELS.has(key):
		return SYSTEM_LABELS[key]
	if key.begins_with("drv:"):
		var p := key.substr(4).split("|", true, 1)
		var src := p[1] if p.size() > 1 else "?"
		var origin := "sumber tidak tercatat (simpanan lama)" if src == SimLedger.UNRECORDED else source_label(src)
		return "%s: %s" % [var_label(p[0]), origin]
	if not key.begins_with("eff:"):
		return key
	var parts := key.substr(4).rsplit("#", true, 1)
	var timing: String = TIMING_LABELS.get(parts[1] if parts.size() > 1 else "", "efek")
	return "%s (%s)" % [source_label(parts[0]), timing]


## Effect source -> readable origin (case title + choice label, or policy name).
static func source_label(source: String) -> String:
	if source.begins_with("policy:"):
		var pid := source.substr(7)
		return "Kebijakan «%s»" % str(ContentDB.policies.get(pid, {}).get("name", pid))
	if source.begins_with("case:"):
		var rest := source.substr(5).split("/", true, 1)
		var c: Dictionary = ContentDB.cases.get(rest[0], {})
		var title := str(c.get("title", rest[0]))
		if rest.size() > 1 and rest[1] == "trigger":
			# A case may label its opening effects (e.g. a data-derived adjustment is not an "event").
			return "%s «%s»" % [str(c.get("trigger_label", "Kejadian kasus")), title]
		if rest.size() > 1 and rest[1].begins_with("choice:"):
			var cid := rest[1].substr(7)
			for ch in c.get("choices", []):
				if str(ch.choice_id) == cid:
					return "Keputusan «%s»: %s" % [title, str(ch.label)]
			return "Keputusan «%s» (pilihan %s)" % [title, cid]
	return source


static func region_name(id: String) -> String:
	return RegionPanel._display_name(ContentDB.region_by_id.get(id, {"name": id, "kind": ""}))


static func scope_label(scope: String, regions: int) -> String:
	if scope == "national":
		return "nasional"
	if scope.begins_with("province:"):
		var p: Dictionary = ContentDB.province_by_id.get(scope.substr(9), {})
		return "Provinsi %s (%d wilayah)" % [str(p.get("name", scope.substr(9))), regions]
	if scope.begins_with("region:"):
		return region_name(scope.substr(7))
	if scope.begins_with("regions:"):
		var ids := scope.substr(8).split(",")
		if ids.size() <= 3:
			return ", ".join(Array(ids).map(func(id): return region_name(id)))
		return "%d wilayah" % ids.size()
	if scope == "all":
		return "semua %d wilayah" % regions
	if scope.begins_with("where:"):
		return "wilayah yang memenuhi syarat saat keputusan"
	return "%d wilayah" % regions


static func effect_line(e: Dictionary) -> String:
	var v := str(e.var)
	var amount: String
	match str(e.op):
		"mul": amount = "×%s" % Fmt.num(float(e.value), 2)
		"set": amount = "= %s" % Fmt.num(float(e.value), 1)
		_: amount = national_value(v, float(e.value), true) if NATIONAL_LABELS.has(v) else Fmt.signed(float(e.value), 1)
	var when := "segera (bulan simulasi berikutnya)" if int(e.delay_months) == 0 else "tertunda %d bulan" % int(e.delay_months)
	if int(e.duration) > 1:
		when += ", selama %d bulan" % int(e.duration)
	var where := scope_label(str(e.scope), int(e.regions))
	if v == "price_pressure":
		where = "nasional, menggeser harga sasaran semua wilayah"
	return "%s %s · %s · %s" % [var_label(v), amount, where, when]


## Compact preview of a case choice for the case modal: where it acts and when. Read from the choice's
## own effects (and its policy), so the preview cannot disagree with what will be scheduled.
static func choice_preview(ch: Dictionary) -> String:
	var places: Array = []
	var national: Array = []
	var max_delay := 0
	var max_end := 0
	for e in ch.get("effects", []):
		var scope := str(e.get("scope", "national"))
		var d := int(e.get("delay", 0))
		max_delay = maxi(max_delay, d)
		max_end = maxi(max_end, d + int(e.get("duration", 1)))
		if scope == "national":
			if str(e["var"]) != "fiscal_space":
				national.append("%s %s" % [var_label(str(e["var"])).to_lower(), national_value(str(e["var"]), float(e.get("value", 0.0)), true)])
			continue
		var n := 0 if not scope.begins_with("province:") else ContentDB.regions.filter(func(r): return str(r.parent_region_id) == scope.substr(9)).size()
		var label := scope_label(scope, n)
		if scope == "all":
			label = "semua wilayah"
		if not places.has(label):
			places.append(label)
	var parts: Array = []
	if not places.is_empty():
		parts.append("Sasaran: " + "; ".join(places))
	if not national.is_empty():
		parts.append("Nasional: " + ", ".join(national))
	if ch.has("enact_policy"):
		var ep: Dictionary = ch.enact_policy
		var tgt: Dictionary = ep.get("target", {})
		var tl := "nasional"
		match str(tgt.get("type", "national")):
			"province": tl = scope_label("province:" + str(tgt.id), 0).split(" (")[0]
			"kabkota": tl = region_name(str(tgt.id))
		var pol: Dictionary = ContentDB.policies.get(str(ep.policy_id), {})
		parts.append("Kebijakan «%s» di %s (mulai %d bulan, berjalan %d bulan)" % [str(pol.get("name", ep.policy_id)), tl,
			int(pol.get("implementation_months", 0)), int(pol.get("duration_months", 0))])
	if max_delay > 0 or max_end > 1:
		parts.append("dampak hingga %d bulan ke depan" % max_end)
	return " · ".join(parts)


## Readable trigger conditions with the CURRENT values, e.g.
## "✓ Rata-rata Kepercayaan di Kota Palu, Kabupaten Sigi = 48,3 (syarat < 54)".
static func describe_conditions(world: SimWorld, cond: Dictionary) -> Array:
	var out: Array = []
	if cond.has("all") or cond.has("any"):
		var subs: Array = cond.get("all", cond.get("any", []))
		for sub in subs:
			out.append_array(describe_conditions(world, sub))
		if cond.has("any") and out.size() > 1:
			out = ["Salah satu:"] + out.map(func(l): return "   " + l)
		return out
	var ok := Conditions.eval(world, cond)
	var mark := "✓ " if ok else "✗ "
	if cond.has("not"):
		var inner: Dictionary = cond["not"]
		if inner.has("case_seen"):
			return [mark + "Kasus «%s» belum pernah muncul" % _case_title(str(inner.case_seen))]
		return [mark + "Bukan: " + ", ".join(describe_conditions(world, inner))]
	if cond.has("tick"):
		var op := str(cond.tick)
		var when := ("mulai bulan ke-%d" % (int(cond.value) + 1)) if op == ">=" else ("bulan ke-%s%d" % [_op_text(op), int(cond.value) + 1])
		return [mark + "Waktu: %s (sekarang bulan ke-%d)" % [when, world.tick + 1]]
	if cond.has("month"):
		var names: Array = (cond.month as Array).map(func(m): return MONTHS[int(m) - 1])
		return [mark + "Musim: %s (sekarang %s)" % [", ".join(names), MONTHS[world.month() - 1]]]
	if cond.has("case_seen"):
		return [mark + "Kasus «%s» sudah muncul" % _case_title(str(cond.case_seen))]
	if cond.has("case_choice"):
		var c: Dictionary = ContentDB.cases.get(str(cond.case_choice), {})
		var label := str(cond.choice)
		for ch in c.get("choices", []):
			if str(ch.choice_id) == str(cond.choice):
				label = str(ch.label)
		return [mark + "Keputusan sebelumnya pada «%s»: %s" % [str(c.get("title", cond.case_choice)), label]]
	if cond.has("policy_active"):
		return [mark + "Kebijakan «%s» sedang berjalan" % str(ContentDB.policies.get(str(cond.policy_active), {}).get("name", cond.policy_active))]
	if cond.has("policy_enacted"):
		return [mark + "Kebijakan «%s» pernah dijalankan" % str(ContentDB.policies.get(str(cond.policy_enacted), {}).get("name", cond.policy_enacted))]
	if cond.has("memory"):
		return [mark + "Catatan sejarah permainan: %s" % str(cond.memory)]
	if cond.has("national"):
		var k := str(cond.national)
		return [mark + "%s = %s (syarat %s%s)" % [var_label(k), national_value(k, float(world.national.get(k, 0.0))),
			_op_text(str(cond.op)), national_value(k, float(cond.value))]]
	if cond.has("var"):
		var scope := str(cond.get("scope", "all"))
		var idx := EffectQueue.resolve_scope(world, scope)
		var arr: PackedFloat64Array = world.vars.get(str(cond["var"]), PackedFloat64Array())
		var agg := str(cond.get("agg", "mean"))
		var val := 0.0
		if not idx.is_empty() and not arr.is_empty():
			val = arr[idx[0]] if agg != "mean" else 0.0
			for i in idx:
				match agg:
					"mean": val += arr[i]
					"max": val = maxf(val, arr[i])
					"min": val = minf(val, arr[i])
			if agg == "mean":
				val /= idx.size()
		var agg_l: String = {"mean": "Rata-rata", "max": "Nilai tertinggi", "min": "Nilai terendah"}.get(agg, agg)
		return [mark + "%s %s di %s = %s (syarat %s%s)" % [agg_l, var_label(str(cond["var"])), scope_label(scope, idx.size()),
			Fmt.num(val, 1), _op_text(str(cond.op)), Fmt.num(float(cond.value), 1)]]
	return [mark + JSON.stringify(cond)]


static func _op_text(op: String) -> String:
	return {">=": "≥ ", "<=": "≤ ", ">": "> ", "<": "< ", "==": "= ", "!=": "≠ "}.get(op, op + " ")


static func _case_title(id: String) -> String:
	return str(ContentDB.cases.get(id, {}).get("title", id))


## One-line toast after a decision: where, how many regions, immediate vs delayed.
static func decision_toast(entry: Dictionary) -> String:
	var regions := {}
	var now := 0
	var later := 0
	for e in entry.get("effects", []):
		if int(e.regions) > 0:
			regions[str(e.scope)] = int(e.regions)
		if int(e.delay_months) == 0:
			now += 1
		else:
			later += 1
	var n := 0
	for k in regions:
		n = maxi(n, int(regions[k]))
	var where := "nasional" if regions.is_empty() else ("hingga %d wilayah" % n)
	return "Keputusan dicatat: %d efek segera (bulan simulasi berikutnya) dan %d efek tertunda · cakupan %s. Lanjutkan kuartal untuk melihat dampaknya." % [now, later, where]


## Multi-line text for the event log panel.
static func entry_text(entry: Dictionary) -> String:
	var when := "Bulan ke-%d" % (int(entry.tick) + 1)
	match str(entry.get("kind", "")):
		"decision", "policy", "case":
			var head: String
			match str(entry.kind):
				"decision": head = "Keputusan «%s»: %s" % [entry.title, entry.choice_label]
				"case": head = "Kasus muncul: «%s»" % entry.title
				_:
					head = "Kebijakan «%s» dijalankan (%d wilayah)" % [entry.title, int(entry.get("regions", 0))]
					if float(entry.get("upfront_fiscal", 0.0)) > 0.0 or float(entry.get("monthly_commitment", 0.0)) > 0.0:
						head += " · biaya awal %s ruang fiskal, komitmen %s%% anggaran/bulan" % [Fmt.num(float(entry.get("upfront_fiscal", 0.0)), 1),
							Fmt.num(float(entry.get("monthly_commitment", 0.0)) * 100.0, 1)]
			var lines: Array = ["%s · %s" % [when, head]]
			for e in entry.get("effects", []):
				lines.append("   • " + effect_line(e))
			if (entry.get("effects", []) as Array).is_empty():
				lines.append("   • tanpa efek langsung pada variabel")
			return "\n".join(lines)
		"quarter":
			var lines: Array = ["Bulan ke-%d–%d · Kuartal disimulasikan untuk semua wilayah%s" % [int(entry.from_tick) + 1, int(entry.tick),
				(" · %d kejadian banjir (wilayah×bulan)" % int(entry.flood_region_months)) if int(entry.flood_region_months) > 0 else ""]]
			for nrow in entry.get("national", []):
				lines.append("   • " + national_line(nrow))
			for vrow in (entry.get("vars", []) as Array).slice(0, 4):
				var top: Array = vrow.top_causes
				var why := ""
				if not top.is_empty():
					why = " · terutama: " + cause_label(str(top[0].cause))
				lines.append("   • %s: rata-rata nasional %s, %d wilayah berubah ≥0,5%s" % [var_label(str(vrow.var)),
					Fmt.signed(float(vrow.national_delta), 2), int(vrow.regions_moved), why])
			if (entry.get("vars", []) as Array).is_empty():
				lines.append("   • tidak ada perubahan berarti")
			return "\n".join(lines)
	return when


## "Ruang fiskal: 48,0 → 39,0 (−9,0) · Keputusan «…»: Relokasi −9,0"
static func national_line(nrow: Dictionary) -> String:
	var k := str(nrow.key)
	var out := "%s: %s → %s (%s)" % [var_label(k), national_value(k, float(nrow.start)), national_value(k, float(nrow.now)),
		national_value(k, float(nrow.now) - float(nrow.start), true)]
	var cs: Array = []
	for c in nrow.get("causes", []):
		cs.append("%s %s" % [cause_label(str(c.cause)), national_value(k, float(c.delta), true)])
	if not cs.is_empty():
		out += " · " + "; ".join(cs)
	return out


static func weighting_label(weighting: String) -> String:
	return "rata-rata berbobot penduduk" if weighting == "population" else "rata-rata setara 514 wilayah (data penduduk belum terkalibrasi)"
