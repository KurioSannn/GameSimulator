class_name CaseEngine
extends RefCounted
## Condition-aware, branching case system (docs/20). Cases are pure data
## (game/data/cases/*.json); this engine evaluates eligibility against SimWorld,
## picks cases deterministically via the world RNG, applies trigger effects and
## schedules choice consequences through EffectQueue.
##
## Condition DSL (JSON) — evaluated by Conditions (shared with PolicyEngine):
##   {"all": [c...]} | {"any": [c...]} | {"not": c}
##   {"tick": ">=", "value": 3}
##   {"var": "damage", "scope": "province:31", "agg": "mean|max|min", "op": ">=", "value": 30}
##   {"national": "food_supply_ratio", "op": "<", "value": 0.9}
##   {"memory": "flood2020_response", "equals": "central"}     (omit equals => truthy)
##   {"case_seen": "CASE-0001"}   {"case_choice": "CASE-0001", "choice": "c"}

const STATUS_ACTIVE := "active"
const STATUS_RESOLVED := "resolved"

var cases: Dictionary  # case_id -> record


func _init(case_records: Dictionary) -> void:
	cases = case_records


func eligible(world: SimWorld) -> Array:
	var out: Array = []
	for id in cases:
		var c: Dictionary = cases[id]
		if world.case_state.has(id) and not _can_recur(world, c, world.case_state[id]):
			continue
		if eval_condition(world, c.get("trigger", {}).get("conditions", {})):
			out.append(id)
	out.sort()  # deterministic order independent of Dictionary insertion
	return out


## Picks one eligible case: highest story_priority tier first, then weighted random within tier.
func pick(world: SimWorld, ids: Array) -> String:
	if ids.is_empty():
		return ""
	var best := -INF
	for id in ids:
		best = maxf(best, float(cases[id].trigger.get("story_priority", 0)))
	var tier: Array = ids.filter(func(id): return float(cases[id].trigger.get("story_priority", 0)) == best)
	var total := 0.0
	for id in tier:
		total += float(cases[id].trigger.get("weight", 1))
	var r := world.rng.randf() * total
	for id in tier:
		r -= float(cases[id].trigger.get("weight", 1))
		if r <= 0.0:
			return id
	return tier[-1]


## Recurring cases (trigger.recurring = {cooldown_ticks, max_occurrences}) may re-open after
## being resolved; non-recurring cases trigger at most once per run.
func _can_recur(world: SimWorld, c: Dictionary, st: Dictionary) -> bool:
	var rec: Dictionary = c.get("trigger", {}).get("recurring", {})
	if rec.is_empty() or st.get("status") == STATUS_ACTIVE:
		return false
	if int(st.get("count", 1)) >= int(rec.get("max_occurrences", 1)):
		return false
	return world.tick - int(st.get("triggered_tick", 0)) >= int(rec.get("cooldown_ticks", 12))


func trigger(world: SimWorld, case_id: String) -> void:
	var c: Dictionary = cases[case_id]
	EffectQueue.schedule(world, c.get("on_trigger_effects", []), "case:%s/trigger" % case_id)
	var prev: Dictionary = world.case_state.get(case_id, {})
	var history: Array = prev.get("history", [])
	world.case_state[case_id] = {"status": STATUS_ACTIVE, "triggered_tick": world.tick,
		"count": int(prev.get("count", 0)) + 1, "history": history}


## Returns "" on success or an error message.
func decide(world: SimWorld, case_id: String, choice_id: String) -> String:
	var st: Dictionary = world.case_state.get(case_id, {})
	if st.get("status") != STATUS_ACTIVE:
		return "Kasus %s tidak aktif." % case_id
	for ch in cases[case_id].get("choices", []):
		if ch.choice_id == choice_id:
			EffectQueue.schedule(world, ch.get("effects", []), "case:%s/choice:%s" % [case_id, choice_id])
			for k in ch.get("memory", {}):
				world.memory[k] = ch.memory[k]
			# String keys via [] (dot-assignment would create StringName keys).
			st["status"] = STATUS_RESOLVED
			st["choice_id"] = choice_id
			st["decided_tick"] = world.tick
			var h: Array = st.get("history", [])
			h.append({"tick": world.tick, "choice": choice_id})
			st["history"] = h
			world.case_state[case_id] = st
			return ""
	return "Pilihan %s tidak ada pada kasus %s." % [choice_id, case_id]


func active_cases(world: SimWorld) -> Array:
	var out: Array = []
	for id in world.case_state:
		if world.case_state[id].status == STATUS_ACTIVE:
			out.append(id)
	out.sort()
	return out


func eval_condition(world: SimWorld, cond: Dictionary) -> bool:
	return Conditions.eval(world, cond)
