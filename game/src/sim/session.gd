class_name Session
extends RefCounted
## One playthrough's turn logic, independent of autoloads/UI so it is testable headless.
## Game (autoload) wraps a Session and adds signals, saves and autosave.

var sim: Simulation
var world: SimWorld
var cases: CaseEngine
var policies: PolicyEngine
## Regional values at the start of the term (from content; identical for every load of the same
## snapshot, so not saved). Baseline for "sejak awal masa jabatan" comparisons.
var initial_vars: Dictionary = {}


func _init(sim_params: Dictionary, regions: Array, baseline: Dictionary, case_records: Dictionary, seed_value: int,
		budget: Dictionary = {}, policy_records: Dictionary = {}) -> void:
	sim = Simulation.new(sim_params, budget)
	world = WorldFactory.build(regions, baseline, sim, seed_value)
	cases = CaseEngine.new(case_records)
	policies = PolicyEngine.new(policy_records, regions)
	for v in SimLedger.TRACKED:
		if world.vars.has(v):
			initial_vars[v] = (world.vars[v] as PackedFloat64Array).duplicate()


func enact_policy(policy_id: String, target: Dictionary) -> String:
	var err := policies.enact(world, policy_id, target)
	if err == "":
		_log_policy(policy_id, "policy")
	return err


func _log_policy(policy_id: String, kind: String) -> void:
	var p: Dictionary = policies.policies.get(policy_id, {})
	SimLedger.log_event(world, SimLedger.scheduled_entry(world, kind, "policy:" + policy_id,
		{"policy_id": policy_id, "title": str(p.get("name", policy_id)),
		"regions": int(world.policy_state.get(policy_id, {}).get("regions", 0)),
		"upfront_fiscal": float(p.get("cost", {}).get("upfront_fiscal", 0.0)),
		"monthly_commitment": float(p.get("cost", {}).get("monthly_commitment", 0.0))}))


## If no case is pending, trigger one eligible case (story priority, then weighted RNG).
func present_next_case() -> String:
	if not cases.active_cases(world).is_empty() or world.is_term_over():
		return ""
	var id := cases.pick(world, cases.eligible(world))
	if id != "":
		cases.trigger(world, id)
		SimLedger.log_event(world, SimLedger.scheduled_entry(world, "case", "case:%s/trigger" % id,
			{"case_id": id, "title": str(cases.cases[id].get("title", id))}))
	return id


func pending_case() -> String:
	var a := cases.active_cases(world)
	return a[0] if not a.is_empty() else ""


## Resolves a case choice. A choice may also enact a data-driven policy
## ("enact_policy": {"policy_id", "target"}), so mechanics (incl. researched local-wisdom ones)
## live in one place. If the policy cannot be enacted, the reason is recorded in memory.
func decide(case_id: String, choice_id: String) -> String:
	var err := cases.decide(world, case_id, choice_id)
	if err != "":
		return err
	var c: Dictionary = cases.cases[case_id]
	for ch in c.get("choices", []):
		if ch.choice_id != choice_id:
			continue
		SimLedger.log_event(world, SimLedger.scheduled_entry(world, "decision", "case:%s/choice:%s" % [case_id, choice_id],
			{"case_id": case_id, "choice_id": choice_id, "title": str(c.get("title", case_id)),
			"choice_label": str(ch.get("label", choice_id)), "fact_class": str(ch.get("fact_class", ""))}))
		if ch.has("enact_policy"):
			var ep: Dictionary = ch.enact_policy
			var perr := policies.enact(world, str(ep.policy_id), ep.get("target", {"type": "national"}))
			if perr != "":
				world.memory["policy_not_enacted:" + str(ep.policy_id)] = perr
			else:
				_log_policy(str(ep.policy_id), "policy")
	return ""


## Advances 3 monthly ticks unless a decision is pending. Returns monthly reports.
## Opens a new change ledger for the quarter (every region; SimLedger) and logs a national summary.
func advance_quarter() -> Array:
	var reports: Array = []
	if pending_case() != "" or world.is_term_over():
		return reports
	SimLedger.begin(world)
	var floods: Array = []
	for _i in SimWorld.TICKS_PER_QUARTER:
		if world.is_term_over():
			break
		var rep: Dictionary = sim.step_month(world)
		floods.append(rep.floods)
		reports.append(rep)
	SimLedger.log_event(world, SimLedger.quarter_entry(world, floods))
	return reports


## Sets the national budget (SIMULATED state). shares: sector -> percent, must cover every
## sector and sum to 100; level within the budget's [level_min, level_max]. Returns "" or error.
func set_budget(level: float, shares: Dictionary) -> String:
	var cfg: Dictionary = sim.budget_cfg
	var sectors: Dictionary = cfg.get("sectors", {})
	if level < float(cfg.get("level_min", 0.8)) - 1e-9 or level > float(cfg.get("level_max", 1.2)) + 1e-9:
		return "Tingkat belanja di luar batas."
	if level > 1.0 and float(world.national.get("fiscal_space", 0.0)) <= 0.0:
		return "Ruang fiskal habis: belanja tidak dapat dinaikkan."
	var total := 0.0
	for sid in sectors:
		if not shares.has(sid):
			return "Porsi sektor %s belum diisi." % sid
		var v := float(shares[sid])
		if v < 0.0:
			return "Porsi sektor tidak boleh negatif."
		total += v
	if absf(total - 100.0) > 0.01:
		return "Total porsi harus 100%% (sekarang %.1f%%)." % total
	world.national["budget_level"] = level
	var clean := {}
	for sid in sectors:
		clean[sid] = float(shares[sid])
	world.national["budget_shares"] = clean
	return ""
