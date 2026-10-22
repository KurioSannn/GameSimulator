class_name Conditions
extends RefCounted
## Shared JSON condition DSL for cases and policies (schema-checkable, no code in content).
##   {"all": [c...]} | {"any": [c...]} | {"not": c}
##   {"tick": ">=", "value": 3}
##   {"var": "damage", "scope": "province:31", "agg": "mean|max|min", "op": ">=", "value": 30}
##   {"national": "fiscal_space", "op": ">=", "value": 10}
##   {"memory": "key", "equals": v}            (omit equals => truthy)
##   {"case_seen": "CASE-0001"}   {"case_choice": "CASE-0001", "choice": "c"}
##   {"policy_active": "POL-..."}               implementing or active now
##   {"policy_enacted": "POL-..."}              ever enacted this run
##   {"month": [8, 9, 10]}                       calendar month of the current tick is in the list


static func eval(world: SimWorld, cond: Dictionary) -> bool:
	if cond.is_empty():
		return true
	if cond.has("all"):
		for sub in cond.all:
			if not eval(world, sub):
				return false
		return true
	if cond.has("any"):
		for sub in cond.any:
			if eval(world, sub):
				return true
		return false
	if cond.has("not"):
		return not eval(world, cond["not"])
	if cond.has("tick"):
		return cmp(float(world.tick), str(cond.tick), float(cond.value))
	if cond.has("month"):
		return world.month() in (cond.month as Array).map(func(m): return int(m))
	if cond.has("case_seen"):
		return world.case_state.has(cond.case_seen)
	if cond.has("case_choice"):
		return world.case_state.get(cond.case_choice, {}).get("choice_id", "") == cond.choice
	if cond.has("policy_active"):
		return PolicyEngine.status_of(world, str(cond.policy_active)) in [PolicyEngine.IMPLEMENTING, PolicyEngine.ACTIVE]
	if cond.has("policy_enacted"):
		return world.policy_state.has(str(cond.policy_enacted))
	if cond.has("memory"):
		if cond.has("equals"):
			return world.memory.get(cond.memory) == cond.equals
		return bool(world.memory.get(cond.memory, false))
	if cond.has("national"):
		return cmp(float(world.national.get(cond.national, 0.0)), str(cond.op), float(cond.value))
	if cond.has("var"):
		var idx := EffectQueue.resolve_scope(world, str(cond.get("scope", "all")))
		if idx.is_empty() or not world.vars.has(cond.var):
			return false
		var arr: PackedFloat64Array = world.vars[cond.var]
		var agg := str(cond.get("agg", "mean"))
		var acc := 0.0 if agg == "mean" else arr[idx[0]]
		for i in idx:
			match agg:
				"mean": acc += arr[i]
				"max": acc = maxf(acc, arr[i])
				"min": acc = minf(acc, arr[i])
		if agg == "mean":
			acc /= idx.size()
		return cmp(acc, str(cond.op), float(cond.value))
	push_error("Conditions: unknown condition %s" % JSON.stringify(cond))
	return false


static func cmp(a: float, op: String, b: float) -> bool:
	match op:
		">": return a > b
		">=": return a >= b
		"<": return a < b
		"<=": return a <= b
		"==": return is_equal_approx(a, b)
		"!=": return not is_equal_approx(a, b)
	push_error("Conditions: unknown operator " + op)
	return false
