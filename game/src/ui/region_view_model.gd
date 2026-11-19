class_name RegionViewModel
extends RefCounted
## Pure, read-only presentation adapter. Explicit resolution; no fallback to a previous selection.
## Aggregates only SIMULATION state. Official facts keep their original administrative resolution.

const METRICS := [
	{"key": "welfare", "label": "KESEJAHTERAAN", "unit": "skala 0–100"},
	{"key": "trust", "label": "KEPERCAYAAN", "unit": "persen"},
	{"key": "infrastructure", "label": "INFRASTRUKTUR", "unit": "skala 0–100"},
	{"key": "services", "label": "LAYANAN PUBLIK", "unit": "skala 0–100"},
	{"key": "environment", "label": "LINGKUNGAN", "unit": "skala 0–100"},
	{"key": "price_level", "label": "INDEKS HARGA", "unit": "indeks model"},
]
const ISLANDS := {"sumatera": "Sumatra", "jawa": "Jawa", "bali_nusa_tenggara": "Bali dan Nusa Tenggara",
	"kalimantan": "Kalimantan", "sulawesi": "Sulawesi", "maluku": "Maluku", "papua": "Papua"}


static func display_name(record: Dictionary) -> String:
	var n := str(record.get("name", "Wilayah tidak dikenal"))
	return "Kabupaten " + n if record.get("kind", "") == "kabupaten" and not n.begins_with("Kab") else n


static func build(w: SimWorld, kind: String, id: String, regions: Array, provinces: Array,
		baseline: Dictionary, case_records: Dictionary = {}, policy_records: Dictionary = {}) -> Dictionary:
	var out := {"kind": kind, "id": id, "valid": false, "name": "WILAYAH TIDAK DITEMUKAN",
		"resolution": "Cakupan tidak tersedia", "record": {}, "indices": PackedInt32Array(),
		"facts": [], "metrics": [], "cases": [], "policies": [], "weighting": "", "baseline_flags": []}
	var record := {}
	if kind == "kabkota":
		for r in regions:
			if str(r.region_id) == id:
				record = r
				break
	elif kind == "province":
		for p in provinces:
			if str(p.region_id) == id:
				record = p
				break
	elif kind == "island_group" and ISLANDS.has(id):
		record = {"name": ISLANDS[id]}
	elif kind == "national":
		record = {"name": "Indonesia"}
	if record.is_empty():
		return out
	var idx := PackedInt32Array()
	for r in regions:
		var matches := kind == "national" or (kind == "kabkota" and str(r.region_id) == id) \
			or (kind == "province" and str(r.parent_region_id) == id) \
			or (kind == "island_group" and str(r.get("island_group", "")) == id)
		if matches and w.region_index.has(str(r.region_id)):
			idx.append(int(w.region_index[str(r.region_id)]))
	if idx.is_empty():
		return out
	out.valid = true
	out.record = record
	out.indices = idx
	out.name = display_name(record)
	out.facts = record.get("facts", []).duplicate(true)
	var resolutions := {"kabkota": str(record.get("kind", "")).capitalize(),
		"province": "Provinsi", "island_group": "Kelompok pulau · navigasi, bukan administrasi", "national": "Nasional"}
	out.resolution = "%s · %d kabupaten/kota" % [resolutions.get(kind, kind), idx.size()]
	out.weighting = weighting(w, idx)
	for spec in METRICS:
		var metric: Dictionary = spec.duplicate()
		var key: String = spec.key
		metric["value"] = null
		metric["delta"] = null
		var flags: Array = []
		if w.vars.has(key):
			metric.value = mean(w, w.vars[key], idx)
			var previous: PackedFloat64Array = w.ledger.get("start", {}).get(key, PackedFloat64Array())
			if not previous.is_empty():
				metric.delta = float(metric.value) - mean(w, previous, idx)
		var bs: Dictionary = baseline.get("variables", {}).get(key, {})
		var raw_statuses: Variant = bs.get("region_status")
		var statuses: Array = raw_statuses if raw_statuses is Array else []
		for i in idx:
			var flag := str(statuses[i]) if i < statuses.size() else str(bs.get("status", "UNKNOWN"))
			if not flags.has(flag):
				flags.append(flag)
			if not out.baseline_flags.has(flag):
				out.baseline_flags.append(flag)
		metric["baseline_flags"] = flags
		out.metrics.append(metric)
	var selected := {}
	for i in idx:
		selected[w.region_ids[i]] = true
	for cid in w.case_state:
		var state: Dictionary = w.case_state[cid]
		var c: Dictionary = case_records.get(cid, {})
		if str(state.get("status", "")) != CaseEngine.STATUS_ACTIVE:
			continue
		var focus: Array = c.get("focus_regions", [])
		if focus.is_empty() or focus.any(func(rid): return selected.has(str(rid))):
			out.cases.append({"id": cid, "title": str(c.get("title", cid))})
	for pid in w.policy_state:
		var state: Dictionary = w.policy_state[pid]
		if PolicyEngine.status_of(w, pid) == PolicyEngine.ENDED:
			continue
		var target: Dictionary = state.get("target", {})
		var affected := PackedInt32Array()
		match str(target.get("type", "")):
			"national": affected = EffectQueue.resolve_scope(w, "all")
			"province": affected = EffectQueue.resolve_scope(w, "province:" + str(target.get("id", "")))
			"kabkota": affected = EffectQueue.resolve_scope(w, "region:" + str(target.get("id", "")))
			"selected": affected = EffectQueue.resolve_scope(w, "regions:" + ",".join(PackedStringArray(target.get("ids", []))))
			"island_group":
				for r in regions:
					if str(r.get("island_group", "")) == str(target.get("id", "")) and w.region_index.has(str(r.region_id)):
						affected.append(int(w.region_index[str(r.region_id)]))
		if Array(affected).any(func(i): return i in idx):
			out.policies.append({"id": pid, "name": str(policy_records.get(pid, {}).get("name", pid)),
				"status": PolicyEngine.status_of(w, pid)})
	return out


static func weighting(w: SimWorld, idx: PackedInt32Array) -> String:
	var population: PackedFloat64Array = w.vars.get("population", PackedFloat64Array())
	for i in idx:
		if i >= population.size() or population[i] <= 0.0:
			return "equal"
	return "population"


static func mean(w: SimWorld, values: PackedFloat64Array, idx: PackedInt32Array) -> float:
	var use_population := weighting(w, idx) == "population"
	var pop: PackedFloat64Array = w.vars.get("population", PackedFloat64Array())
	var total := 0.0
	var weights := 0.0
	for i in idx:
		var weight := pop[i] if use_population else 1.0
		total += values[i] * weight
		weights += weight
	return total / weights if weights > 0.0 else 0.0
