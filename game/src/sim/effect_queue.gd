class_name EffectQueue
extends RefCounted
## Data-driven state effects with optional delay and duration.
##
## Effect record (plain Dictionary so it serializes directly into saves and can be
## authored in content JSON):
##   scope:    "national" | "all" | "region:<id>" | "province:<code>" | "regions:<id>,<id>"
##             | "where:<var><op><value>[&in:<id>,<id>]" (e.g. "where:flood_damage_last>0&in:31.71,32.01"),
##               resolved to an explicit "regions:" list AT SCHEDULING TIME, so a decision targets the
##               regions affected now; "&in:" restricts candidates (e.g. to a case's own area)
##   var:      regional variable name, or national key when scope == "national"
##   op:       "add" | "mul" | "set"
##   value:    float
##   delay:    months before first application (0 = this tick)        [authoring only]
##   duration: months the effect re-applies each tick (default 1)
##   source:   provenance label, e.g. "case:CASE-0001/choice:b"
##   scale_by: optional per-region response {var, mode, ref, min, max} (add/mul ops only):
##             mode "capacity": m_i = clamp(var_i / ref, min, max)          (stronger capacity, more effect)
##             mode "gap":      m_i = clamp((100 - var_i) / (100 - ref), min, max)  (more effect where var is low)
##             The value applied to region i is value x m_i ("add") or 1 + (value - 1) x m_i ("mul").
## Runtime fields: apply_tick, remaining, scheduled_tick (tick of the decision; tells SimLedger whether an
## application is immediate or delayed), repeat (true on re-applications of a multi-month effect).

const VALID_OPS := ["add", "mul", "set"]


static func make(spec: Dictionary, now_tick: int, source: String) -> Dictionary:
	var e := {
		"scope": str(spec.get("scope", "national")),
		"var": str(spec["var"]),
		"op": str(spec.get("op", "add")),
		"value": float(spec.get("value", 0.0)),
		"apply_tick": now_tick + int(spec.get("delay", 0)),
		"remaining": max(1, int(spec.get("duration", 1))),
		"source": source,
		"scheduled_tick": now_tick,
	}
	if spec.has("scale_by"):
		e["scale_by"] = (spec["scale_by"] as Dictionary).duplicate()
	assert(e.op in VALID_OPS, "invalid effect op %s" % e.op)
	return e


static func schedule(world: SimWorld, specs: Array, source: String) -> void:
	for s in specs:
		var spec: Dictionary = s
		var scope := str(spec.get("scope", "national"))
		if scope.begins_with("where:"):
			var idx := resolve_where(world, scope.substr(6))
			if idx.is_empty():
				continue  # nobody matches: effect has no target
			var ids := PackedStringArray()
			for i in idx:
				ids.append(world.region_ids[i])
			spec = spec.duplicate()
			spec.scope = "regions:" + ",".join(ids)
		world.pending_effects.append(make(spec, world.tick, source))


## "<var><op><value>" with op in >=, <=, >, <  ->  indices of matching regions.
static func resolve_where(world: SimWorld, expr: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var allowed := {}
	if expr.contains("&in:"):
		var parts := expr.split("&in:", true, 1)
		expr = parts[0]
		for id in parts[1].split(","):
			if world.region_index.has(id):
				allowed[world.region_index[id]] = true
	var re := RegEx.create_from_string("^([a-z_]+)(>=|<=|>|<)(-?[0-9.]+)$")
	var m := re.search(expr)
	if m == null or not world.vars.has(m.get_string(1)):
		push_error("EffectQueue: invalid where-scope '%s'" % expr)
		return out
	var arr: PackedFloat64Array = world.vars[m.get_string(1)]
	var op := m.get_string(2)
	var v := float(m.get_string(3))
	for i in arr.size():
		if not allowed.is_empty() and not allowed.has(i):
			continue
		var x := arr[i]
		if (op == ">" and x > v) or (op == ">=" and x >= v) or (op == "<" and x < v) or (op == "<=" and x <= v):
			out.append(i)
	return out


## Applies every effect due at world.tick. Returns the list of applied effects (for UI/logs).
static func apply_due(world: SimWorld, var_bounds: Dictionary) -> Array:
	var applied: Array = []
	var keep: Array = []
	for e in world.pending_effects:
		if int(e.apply_tick) > world.tick:
			keep.append(e)
			continue
		var before := SimLedger.snapshot(world, [e.var]) if e.scope != "national" else {}
		_apply(world, e, var_bounds)
		SimLedger.record(world, SimLedger.effect_cause(e), before)
		applied.append(e)
		var rem := int(e.remaining) - 1
		if rem > 0:
			var next: Dictionary = e.duplicate()
			next.remaining = rem
			next.apply_tick = world.tick + 1
			next.repeat = true
			keep.append(next)
	world.pending_effects = keep
	return applied


static func resolve_scope(world: SimWorld, scope: String) -> PackedInt32Array:
	# Static scopes (all/region/regions/province) never change for a world; cache them. "where:" scopes
	# depend on live state and are never cached.
	if not scope.begins_with("where:"):
		var cached: Variant = world.scope_cache.get(scope)
		if cached != null:
			return cached
		var res := _resolve_static(world, scope)
		world.scope_cache[scope] = res
		return res
	return resolve_where(world, scope.substr(6))


static func _resolve_static(world: SimWorld, scope: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	if scope == "all":
		for i in world.region_count():
			out.append(i)
	elif scope.begins_with("region:"):
		var id := scope.substr(7)
		if world.region_index.has(id):
			out.append(world.region_index[id])
	elif scope.begins_with("regions:"):
		for id in scope.substr(8).split(","):
			if world.region_index.has(id):
				out.append(world.region_index[id])
	elif scope.begins_with("province:"):
		var pidx := world.province_ids.find(scope.substr(9))
		if pidx >= 0:
			for i in world.region_count():
				if world.province_of[i] == pidx:
					out.append(i)
	return out


static func _apply(world: SimWorld, e: Dictionary, var_bounds: Dictionary) -> void:
	var v: String = e.var
	var val: float = e.value
	if e.scope == "national":
		var cur := float(world.national.get(v, 0.0))
		var nv := _op(cur, e.op, val)
		world.national[v] = nv
		SimLedger.national_change(world, v, nv - cur, SimLedger.effect_cause(e))
		SimLedger.driver_add(world, v, str(e.source), nv - cur)
		return
	if not world.vars.has(v):
		push_error("EffectQueue: unknown regional var '%s' (%s)" % [v, e.source])
		return
	var arr: PackedFloat64Array = world.vars[v]
	var b: Dictionary = var_bounds.get(v, {})
	var lo := float(b.get("min", -INF))
	var hi := float(b.get("max", INF))
	var sb: Dictionary = e.get("scale_by", {})
	var sarr: PackedFloat64Array = world.vars.get(str(sb.get("var", "")), PackedFloat64Array()) if not sb.is_empty() else PackedFloat64Array()
	for i in resolve_scope(world, e.scope):
		var vi := val
		if not sarr.is_empty():
			var m := region_multiplier(sb, sarr[i])
			vi = val * m if e.op == "add" else (1.0 + (val - 1.0) * m if e.op == "mul" else val)
		arr[i] = clampf(_op(arr[i], e.op, vi), lo, hi)
	world.vars[v] = arr


static func _op(cur: float, op: String, val: float) -> float:
	match op:
		"add": return cur + val
		"mul": return cur * val
		"set": return val
	return cur


static func region_multiplier(sb: Dictionary, x: float) -> float:
	var ref := float(sb.get("ref", 50.0))
	var lo := float(sb.get("min", 0.25))
	var hi := float(sb.get("max", 2.0))
	if str(sb.get("mode", "capacity")) == "gap":
		return clampf((100.0 - x) / maxf(100.0 - ref, 1e-6), lo, hi)
	return clampf(x / maxf(ref, 1e-6), lo, hi)
