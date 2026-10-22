class_name SimLedger
extends RefCounted
## Exact per-region attribution of what changed during the current/last quarter, and why.
##
## Observational only: it never changes simulation state, uses no RNG, and so cannot alter outcomes
## (golden masters stay bit-identical). Every monthly system step and every applied effect records the
## delta it produced for each tracked variable; because the steps run in sequence, the recorded causes
## of a variable sum exactly to (value now - value at quarter start) for every region.
##
## world.ledger layout (saved with the world, schema >= 4):
##   start_tick: int                 tick at which the quarter began
##   start:  {var: PackedFloat64Array}            values at quarter start
##   causes: {var: {cause_key: PackedFloat64Array}} summed deltas per region
## Cause keys: "sys:<system>" (model dynamics, sim_params.json coefficients) or
##             "eff:<source>#<now|delayed|ongoing>" (case/policy effect; "now" = applied in the first month
##             after the decision, "delayed" = first application after a delay, "ongoing" = re-application of
##             a multi-month effect).

## Variables explained to the player (regional panel + map). welfare_base is tracked because long-term
## decisions move it (e.g. CASE-0005 industrial income); population, sentiment_base and per-month
## transients (flood_*_last) are not.
const TRACKED := ["welfare", "welfare_base", "price_level", "food_supply", "food_capacity", "infrastructure", "logistics",
	"services", "damage", "environment", "trust", "sentiment", "flood_protection", "fire_prevention",
	"flood_frequency", "flood_risk_profile"]

## Which variables each monthly system writes (Simulation.step_month), for cheap snapshots.
const SYSTEM_WRITES := {
	"budget": ["infrastructure", "services", "food_capacity", "flood_protection"],
	"floods": ["damage"],
	"recovery": ["damage", "logistics"],
	"food_prices": ["food_supply", "price_level"],
	"welfare": ["welfare"],
	"sentiment": ["sentiment", "trust"],
}

const LOG_CAP := 40
## National scalars explained per quarter (decision costs, commodity shock) and national drivers whose
## value is split by source because they move every region (price_pressure raises all price targets).
const NATIONAL_TRACKED := ["fiscal_space", "price_pressure"]
const DRIVEN := ["price_pressure"]
const UNRECORDED := "?"  # driver value from before source tracking (pre-v5 saves)


static func active(world: SimWorld) -> bool:
	return world.ledger.has("start")


## Opens a new quarter: snapshot of tracked values; causes cleared.
static func begin(world: SimWorld) -> void:
	var start := {}
	for v in TRACKED:
		if world.vars.has(v):
			start[v] = (world.vars[v] as PackedFloat64Array).duplicate()
	var nstart := {}
	for k in NATIONAL_TRACKED:
		nstart[k] = float(world.national.get(k, 0.0))
	world.ledger = {"start_tick": world.tick, "start": start, "causes": {},
		"fiscal_space_start": float(world.national.get("fiscal_space", 0.0)),
		"national_start": nstart, "national_causes": {}}


## Records a change of a national scalar to `cause` (no-op outside a quarter or for untracked keys).
static func national_change(world: SimWorld, key: String, delta: float, cause: String) -> void:
	if delta == 0.0 or not active(world) or not key in NATIONAL_TRACKED or not world.ledger.has("national_causes"):
		return
	var per: Dictionary = world.ledger.national_causes.get(key, {})
	per[cause] = float(per.get(cause, 0.0)) + delta
	world.ledger.national_causes[key] = per


## Driver bookkeeping (always on, observational): an effect source adds its delta to its share.
static func driver_add(world: SimWorld, key: String, source: String, delta: float) -> void:
	if delta == 0.0 or not key in DRIVEN:
		return
	var shares: Dictionary = world.drivers.get(key, {})
	shares[source] = float(shares.get(source, 0.0)) + delta
	world.drivers[key] = shares


## Source fractions of the driver's current value (they sum to 1). Any part not covered by recorded
## shares (old saves) is reported as UNRECORDED rather than silently redistributed.
static func driver_fractions(world: SimWorld, key: String, value: float) -> Dictionary:
	var out := {}
	if value == 0.0:
		return out
	var shares: Dictionary = world.drivers.get(key, {})
	var covered := 0.0
	for s in shares:
		covered += float(shares[s])
		out[s] = float(shares[s]) / value
	if absf(value - covered) > 1e-12:
		out[UNRECORDED] = (value - covered) / value
	return out


## Keeps shares consistent after the model changes the driver (decay, clamping): every share scales
## by the same factor, so a fading shock fades for each of its sources proportionally.
static func driver_rescale(world: SimWorld, key: String, before: float, after: float) -> void:
	if not world.drivers.has(key):
		return
	var fr := driver_fractions(world, key, before)
	var shares := {}
	for s in fr:
		if after != 0.0:
			shares[s] = float(fr[s]) * after
	if before == 0.0 and after == 0.0:
		return  # e.g. +x and -x cancelling: keep as is
	world.drivers[key] = shares


## Moves `part` (per region) of an already recorded cause to driver sources, by fraction.
## Totals per region are unchanged, so causes still sum exactly to the change.
static func split(world: SimWorld, v: String, from_cause: String, part: PackedFloat64Array, fracs: Dictionary, prefix: String) -> void:
	if part.is_empty() or fracs.is_empty() or not active(world):
		return
	var per_var: Dictionary = world.ledger.causes.get(v, {})
	var base: PackedFloat64Array = per_var.get(from_cause, PackedFloat64Array())
	if base.is_empty():
		return
	var moved := PackedFloat64Array()
	moved.resize(part.size())
	for src in fracs:
		var f := float(fracs[src])
		var acc: PackedFloat64Array = per_var.get(prefix + str(src), PackedFloat64Array())
		if acc.is_empty():
			acc.resize(part.size())
		for i in part.size():
			var x := part[i] * f
			acc[i] += x
			moved[i] += x
		per_var[prefix + str(src)] = acc
	for i in part.size():
		base[i] -= moved[i]
	per_var[from_cause] = base
	world.ledger.causes[v] = per_var


## Snapshot of the tracked variables among `var_names` (taken before a step).
static func snapshot(world: SimWorld, var_names: Array) -> Dictionary:
	var out := {}
	if not active(world):
		return out
	for v in var_names:
		if v in TRACKED and world.vars.has(v):
			out[v] = (world.vars[v] as PackedFloat64Array).duplicate()
	return out


## Adds (after - before) to `cause` for each snapshotted variable. Unchanged variables add nothing.
static func record(world: SimWorld, cause: String, before: Dictionary) -> void:
	if before.is_empty():
		return
	var causes: Dictionary = world.ledger.causes
	for v in before:
		var b: PackedFloat64Array = before[v]
		var a: PackedFloat64Array = world.vars[v]
		var changed := false
		for i in a.size():
			if a[i] != b[i]:
				changed = true
				break
		if not changed:
			continue
		var per_var: Dictionary = causes.get(v, {})
		var acc: PackedFloat64Array = per_var.get(cause, PackedFloat64Array())
		if acc.is_empty():
			acc.resize(a.size())
		for i in a.size():
			acc[i] += a[i] - b[i]
		per_var[cause] = acc
		causes[v] = per_var


static func effect_cause(e: Dictionary) -> String:
	var timing := "now" if int(e.get("apply_tick", -1)) == int(e.get("scheduled_tick", -2)) else "delayed"
	if e.get("repeat", false):
		timing = "ongoing"
	return "eff:%s#%s" % [str(e.get("source", "?")), timing]


## What changed in region i during the ledger's quarter: one row per tracked variable that moved,
## largest causes first. Rows: {var, start, now, delta, causes: [{cause, delta}]}.
static func region_changes(world: SimWorld, i: int, min_abs: float = 0.05) -> Array:
	var rows: Array = []
	if not active(world):
		return rows
	for v in world.ledger.start:
		var s: float = (world.ledger.start[v] as PackedFloat64Array)[i]
		var now: float = world.vars[v][i]
		var causes: Array = []
		for c in world.ledger.causes.get(v, {}):
			var d: float = (world.ledger.causes[v][c] as PackedFloat64Array)[i]
			if absf(d) >= min_abs * 0.5:
				causes.append({"cause": c, "delta": d})
		causes.sort_custom(func(a, b): return absf(a.delta) > absf(b.delta))
		if absf(now - s) >= min_abs or not causes.is_empty():
			rows.append({"var": v, "start": s, "now": now, "delta": now - s, "causes": causes})
	rows.sort_custom(func(a, b): return absf(a.delta) > absf(b.delta))
	return rows


## Per-region change of `v` over the ledger's quarter (for the map's change mode).
static func deltas(world: SimWorld, v: String) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if not active(world) or not world.ledger.start.has(v):
		return out
	var s: PackedFloat64Array = world.ledger.start[v]
	var now: PackedFloat64Array = world.vars[v]
	out.resize(now.size())
	for i in now.size():
		out[i] = now[i] - s[i]
	return out


## National summary of the quarter for the event log: per variable the change of the national
## aggregate (same weighting as SimWorld.national_mean), regions that moved noticeably, top causes.
static func quarter_entry(world: SimWorld, floods_by_month: Array) -> Dictionary:
	var vars_out: Array = []
	for v in world.ledger.start:
		var d := deltas(world, v)
		var moved := 0
		for x in d:
			if absf(x) >= 0.5:
				moved += 1
		var nat_delta := world.national_mean(v) - _mean_of(world, world.ledger.start[v])
		var top: Array = []
		for c in world.ledger.causes.get(v, {}):
			var arr: PackedFloat64Array = world.ledger.causes[v][c]
			var n := 0
			for x in arr:
				if absf(x) >= 0.05:
					n += 1
			top.append({"cause": c, "national_delta": world.weighted_mean_of(arr), "regions": n})
		top.sort_custom(func(a, b): return absf(a.national_delta) > absf(b.national_delta))
		if moved > 0 or absf(nat_delta) >= 0.01:
			vars_out.append({"var": v, "national_delta": nat_delta, "regions_moved": moved, "top_causes": top.slice(0, 3)})
	vars_out.sort_custom(func(a, b): return a.regions_moved > b.regions_moved)
	var flooded := 0
	for f in floods_by_month:
		flooded += int(f)
	var nat: Array = []
	for k in world.ledger.get("national_start", {}):
		var s0 := float(world.ledger.national_start[k])
		var now := float(world.national.get(k, 0.0))
		var causes: Array = []
		for c in world.ledger.get("national_causes", {}).get(k, {}):
			causes.append({"cause": c, "delta": float(world.ledger.national_causes[k][c])})
		causes.sort_custom(func(a, b): return absf(a.delta) > absf(b.delta))
		if absf(now - s0) > 1e-9 or not causes.is_empty():
			nat.append({"key": k, "start": s0, "now": now, "causes": causes.slice(0, 3)})
	return {"kind": "quarter", "tick": world.tick, "from_tick": int(world.ledger.start_tick),
		"weighting": world.national_weighting(), "flood_region_months": flooded, "vars": vars_out, "national": nat}


## Decision/policy entry: which effects were scheduled, where, when, by which rule.
static func scheduled_entry(world: SimWorld, kind: String, source: String, extra: Dictionary) -> Dictionary:
	var effects: Array = []
	for e in world.pending_effects:
		if str(e.source) != source or int(e.get("scheduled_tick", -1)) != world.tick:
			continue
		var n := -1 if e.scope == "national" else EffectQueue.resolve_scope(world, e.scope).size()
		effects.append({"var": e.var, "scope": e.scope, "regions": n, "op": e.op, "value": e.value,
			"delay_months": int(e.apply_tick) - world.tick, "duration": int(e.remaining)})
	var entry := {"kind": kind, "tick": world.tick, "source": source, "effects": effects}
	entry.merge(extra)
	return entry


static func log_event(world: SimWorld, entry: Dictionary) -> void:
	world.event_log.append(entry)
	if world.event_log.size() > LOG_CAP:
		world.event_log = world.event_log.slice(world.event_log.size() - LOG_CAP)


static func _mean_of(world: SimWorld, arr: PackedFloat64Array) -> float:
	return world.weighted_mean_of(arr)
