class_name SimWorld
extends RefCounted
## Authoritative dynamic game state.
##
## Regional state is stored structure-of-arrays: one PackedFloat64Array per variable,
## indexed by region index (0..region_count-1). There are no per-region Nodes; the
## monthly tick is a single centralized loop over every region (docs/07, D-004).

const SAVE_SCHEMA := 5  # v5: drivers; v4: ledger + event_log; v3: policy_state; v2: exact floats (SaveCodec); older versions migrated on load
const TICKS_PER_QUARTER := 3
const QUARTERS_PER_YEAR := 4
const TERM_YEARS := 5
const TERM_TICKS := TICKS_PER_QUARTER * QUARTERS_PER_YEAR * TERM_YEARS  # 60

var region_ids: PackedStringArray = []
var region_index: Dictionary = {}          # region_id -> int
var province_ids: PackedStringArray = []
var province_of: PackedInt32Array = []     # region index -> province index

var vars: Dictionary = {}                  # var name -> PackedFloat64Array (len = region_count)
var national: Dictionary = {}              # national scalars, e.g. budget_rp
var tick: int = 0                          # months elapsed in the term
var rng := RandomNumberGenerator.new()
var rng_seed: int = 0

## Effects scheduled for future ticks. Each entry: see EffectQueue.make().
var pending_effects: Array = []
## Historical memory: decision/case flags that later cases and dialogue react to.
var memory: Dictionary = {}
## Case engine state: case_id -> {status, triggered_tick, choice_id, ...}
var case_state: Dictionary = {}
## Policy engine state: policy_id -> {enacted_tick, target, impl_end_tick, end_tick, commitment, ...}
var policy_state: Dictionary = {}
## Change attribution of the current/last quarter (SimLedger): what changed per region and why.
var ledger: Dictionary = {}
## Decision and quarter summaries for the player (SimLedger.log_event; capped).
var event_log: Array = []
## Which effect sources make up a national driver's current value, e.g.
## {"price_pressure": {"case:CASE-0003/trigger": 0.06, "case:CASE-0003/choice:a": -0.04}} (SimLedger; observational).
var drivers: Dictionary = {}
## Calendar month of tick 0 (1 = January); set from sim_params by WorldFactory (not saved: content constant).
var start_month: int = 1
## Runtime-only cache: static scope string -> region indices (not saved; rebuilt on demand).
var scope_cache: Dictionary = {}


func region_count() -> int:
	return region_ids.size()


func setup_regions(ids: PackedStringArray, parent_ids: PackedStringArray, var_names: Array) -> void:
	region_ids = ids
	region_index.clear()
	province_ids = []
	var prov_index := {}
	province_of.resize(ids.size())
	for i in ids.size():
		region_index[ids[i]] = i
		var p := parent_ids[i]
		if not prov_index.has(p):
			prov_index[p] = province_ids.size()
			province_ids.append(p)
		province_of[i] = prov_index[p]
	vars.clear()
	for v in var_names:
		var arr := PackedFloat64Array()
		arr.resize(ids.size())
		arr.fill(0.0)
		vars[v] = arr


func seed_rng(seed_value: int) -> void:
	rng_seed = seed_value
	rng.seed = seed_value


func month() -> int:
	return (start_month - 1 + tick) % 12 + 1


func quarter_index() -> int:
	return tick / TICKS_PER_QUARTER  # 0..19


func year_index() -> int:
	return tick / (TICKS_PER_QUARTER * QUARTERS_PER_YEAR)  # 0..4


func is_term_over() -> bool:
	return tick >= TERM_TICKS


func get_v(var_name: String, i: int) -> float:
	return vars[var_name][i]


func set_v(var_name: String, i: int, value: float) -> void:
	var arr: PackedFloat64Array = vars[var_name]
	arr[i] = value
	vars[var_name] = arr  # Packed arrays are copy-on-write; write back.


## National mean of a regional variable. Population-weighted only when every region has a
## population > 0; otherwise an equal-weighted mean over all regions (no mixed weighting, which would
## silently over-weight the regions that happen to have data). See national_weighting().
func national_mean(var_name: String, weight_var: String = "population") -> float:
	return weighted_mean_of(vars[var_name], weight_var)


func weighted_mean_of(a: PackedFloat64Array, weight_var: String = "population") -> float:
	if a.is_empty():
		return 0.0
	var use_w := national_weighting(weight_var) == "population"
	var w: PackedFloat64Array = vars.get(weight_var, PackedFloat64Array())
	var sum := 0.0
	var wsum := 0.0
	for i in a.size():
		var wi := w[i] if use_w else 1.0
		sum += a[i] * wi
		wsum += wi
	return sum / wsum if wsum > 0.0 else 0.0


## "population" if every region has a positive weight, else "equal".
func national_weighting(weight_var: String = "population") -> String:
	var w: PackedFloat64Array = vars.get(weight_var, PackedFloat64Array())
	if w.size() != region_ids.size() or w.is_empty():
		return "equal"
	for x in w:
		if not (x > 0.0):
			return "equal"
	return "population"


func to_dict() -> Dictionary:
	var v := {}
	for k in vars:
		v[k] = SaveCodec.encode_array(vars[k])
	return {
		"schema": SAVE_SCHEMA,
		"region_ids": Array(region_ids),
		"tick": tick,
		"rng_seed": rng_seed,
		"rng_state": str(rng.state),  # 64-bit; string avoids JSON float precision loss
		"national": SaveCodec.encode(national),
		"vars": v,
		"pending_effects": SaveCodec.encode(pending_effects),
		"memory": SaveCodec.encode(memory),
		"case_state": SaveCodec.encode(case_state),
		"policy_state": SaveCodec.encode(policy_state),
		"ledger": SaveCodec.encode(ledger),
		"event_log": SaveCodec.encode(event_log),
		"drivers": SaveCodec.encode(drivers),
	}


## Restores dynamic state into a world whose regions were already set up from the
## same content snapshot. Returns "" on success or a human-readable error.
func load_dict(d: Dictionary) -> String:
	var schema := int(d.get("schema", -1))
	if schema == 1:
		d = _migrate_v1(d)
		schema = 2
	if schema == 2:
		d = d.duplicate()
		d["policy_state"] = {}  # v2 saves predate the policy system
		d["schema"] = 3
		schema = 3
	if schema == 3:
		d = d.duplicate()
		d["ledger"] = {}  # v3 saves predate change attribution: the panel shows changes from the next quarter on
		d["event_log"] = []
		d["schema"] = 4
		schema = 4
	if schema == 4:
		d = d.duplicate()
		d["drivers"] = {}  # pre-v5: an existing price pressure is shown as "sumber tidak tercatat"
		d["schema"] = SAVE_SCHEMA
		schema = SAVE_SCHEMA
	if schema != SAVE_SCHEMA:
		return "Versi data simpanan tidak didukung (%s)." % str(d.get("schema"))
	var ids: Array = d.get("region_ids", [])
	if ids.size() != region_ids.size():
		return "Jumlah wilayah pada simpanan (%d) tidak cocok dengan data permainan (%d)." % [ids.size(), region_ids.size()]
	for i in ids.size():
		if str(ids[i]) != region_ids[i]:
			return "Urutan/kode wilayah pada simpanan tidak cocok (%s)." % str(ids[i])
	var dv: Dictionary = d.get("vars", {})
	var decoded := {}
	for k in vars:
		if not dv.has(k):
			return "Variabel '%s' hilang dari simpanan." % k
		var arr := SaveCodec.decode_array(str(dv[k]))
		if arr.size() != region_ids.size():
			return "Panjang variabel '%s' tidak valid." % k
		decoded[k] = arr
	for k in vars:
		vars[k] = decoded[k]
	tick = int(d["tick"])
	rng_seed = int(d["rng_seed"])
	rng.seed = rng_seed
	rng.state = int(str(d["rng_state"]))
	national = SaveCodec.decode(d.get("national", {}))
	pending_effects = SaveCodec.decode(d.get("pending_effects", []))
	memory = SaveCodec.decode(d.get("memory", {}))
	case_state = SaveCodec.decode(d.get("case_state", {}))
	policy_state = SaveCodec.decode(d.get("policy_state", {}))
	ledger = SaveCodec.decode(d.get("ledger", {}))
	event_log = SaveCodec.decode(d.get("event_log", []))
	drivers = SaveCodec.decode(d.get("drivers", {}))
	return ""


## v1 stored plain JSON numbers (lossy for ~9% of doubles). Convert to the v2 layout; values are
## kept as stored (the precision lost in v1 cannot be recovered, but the save stays playable).
static func _migrate_v1(d: Dictionary) -> Dictionary:
	var m := d.duplicate(true)
	var v := {}
	for k in d.get("vars", {}):
		v[k] = SaveCodec.encode_array(PackedFloat64Array(d.vars[k]))
	m.vars = v
	for key in ["national", "pending_effects", "memory", "case_state"]:
		m[key] = SaveCodec.encode(_v1_numbers(d.get(key, {} if key != "pending_effects" else [])))
	m.schema = 2
	return m


## In v1 every number is a JSON float; keep whole numbers as int, others as float.
static func _v1_numbers(x: Variant) -> Variant:
	match typeof(x):
		TYPE_FLOAT:
			return int(x) if x == floorf(x) and absf(x) < 1e15 else x
		TYPE_DICTIONARY:
			var o := {}
			for k in x:
				o[str(k)] = _v1_numbers(x[k])
			return o
		TYPE_ARRAY:
			return (x as Array).map(func(e): return _v1_numbers(e))
	return x
