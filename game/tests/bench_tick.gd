extends SceneTree
## Benchmarks (headless). Prints JSON lines for reports.
##   Godot --headless --path game -s res://tests/bench_tick.gd
## Scenarios:
##   reference  : real content (all cases), floods only where CASE-0001 reveals exposure, baseline budget
##   worst_case : flood frequency 20/yr (2024 max) in ALL regions, non-baseline budget (every loop active), all cases
##   stress_Nx  : worst case with N x region copies (scalability headroom)
## Measures: monthly tick (median/p95/max), case engine eligibility per quarter, full save
## (encode + JSON + checksum + atomic write) and load (read + verify + decode) per slot.

var _p: Dictionary
var _regions: Array
var _baseline: Dictionary
var _budget: Dictionary
var _cases := {}
var _policies := {}


func _json(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _initialize() -> void:
	_p = _json("res://data/sim_params.json")
	_regions = _json("res://data/regions.json").regions
	_baseline = _json("res://data/baseline.json")
	_budget = _json("res://data/budget.json")
	for f in DirAccess.get_files_at("res://data/cases"):
		var c: Dictionary = _json("res://data/cases/" + f)
		_cases[c.case_id] = c
	for f in DirAccess.get_files_at("res://data/policies"):
		var pr: Dictionary = _json("res://data/policies/" + f)
		_policies[pr.policy_id] = pr
	print("godot ", Engine.get_version_info().string, " | ", OS.get_processor_name(), " | ", OS.get_name())
	_run("reference", _regions, false)
	_run("worst_case", _regions, true)
	_run("policies_active", _regions, true, true)
	for mult in [4, 10]:
		var rs: Array = []
		for k in mult:
			for r in _regions:
				var c: Dictionary = r.duplicate()
				c.region_id = "%s#%d" % [r.region_id, k]
				rs.append(c)
		_run("stress_%dx" % mult, rs, true)
	quit(0)


func _run(name: String, regions: Array, worst: bool, with_policies := false) -> void:
	var real := regions.size() == _regions.size()
	var s := Session.new(_p, regions, _baseline if real else {}, _cases if real else {}, 1, _budget, _policies if real else {})
	var enacted := 0
	if with_policies:
		for pid in ["POL-PANGAN-IRIGASI", "POL-KEBENCANAAN-DRAINASE", "POL-SOSIAL-BLT", "POL-INFRA-JALAN", "POL-LAYANAN-DAERAH"]:
			if s.enact_policy(pid, {"type": "national"}) == "":
				enacted += 1
	if not real:  # copies have synthetic ids; apply defaults explicitly
		for v in s.sim.var_names():
			var a: PackedFloat64Array = s.world.vars[v]
			a.fill(float(_baseline.variables[v].default))
			s.world.vars[v] = a
	if worst:
		var e: PackedFloat64Array = s.world.vars["flood_frequency"]
		e.fill(20.0)  # BNPB 2024 maximum recorded (Luwu) applied to every region
		s.world.vars["flood_frequency"] = e
		var sh: Dictionary = s.world.national.budget_shares.duplicate()
		sh.kebencanaan += 5.0
		sh.layanan -= 5.0
		s.set_budget(1.05, sh)
	var ticks := PackedFloat64Array()
	var case_ms := PackedFloat64Array()
	var floods := 0
	var t_all := Time.get_ticks_usec()
	s.present_next_case()
	while not s.world.is_term_over():
		var pend := s.pending_case()
		if pend != "":
			s.decide(pend, "b")
		for _m in 3:
			if s.world.is_term_over():
				break
			var t0 := Time.get_ticks_usec()
			var rep := s.sim.step_month(s.world)
			ticks.append((Time.get_ticks_usec() - t0) / 1000.0)
			floods += int(rep.floods)
		var t1 := Time.get_ticks_usec()
		s.present_next_case()
		case_ms.append((Time.get_ticks_usec() - t1) / 1000.0)
	var total_ms := (Time.get_ticks_usec() - t_all) / 1000.0
	ticks.sort()
	case_ms.sort()
	var svc := SaveService.new("user://bench_saves")
	var ts := Time.get_ticks_usec()
	svc.save("bench", "bench", s.world.to_dict())
	var save_ms := (Time.get_ticks_usec() - ts) / 1000.0
	var tl := Time.get_ticks_usec()
	var r := svc.load_slot("bench")
	var w2 := WorldFactory.build(regions, _baseline if real else {}, s.sim, 1)
	var lerr: String = w2.load_dict(r.payload) if r.ok else str(r.error)
	var load_ms := (Time.get_ticks_usec() - tl) / 1000.0
	print(JSON.stringify({
		"scenario": name, "regions": s.world.region_count(), "ticks": ticks.size(), "flood_events": floods,
		"tick_ms_median": snappedf(ticks[ticks.size() / 2], 0.001), "tick_ms_p95": snappedf(ticks[int(ticks.size() * 0.95)], 0.001),
		"tick_ms_max": snappedf(ticks[-1], 0.001), "case_eval_ms_max": snappedf(case_ms[-1], 0.001),
		"term_total_ms": snappedf(total_ms, 0.1), "save_ms": snappedf(save_ms, 0.01), "load_ms": snappedf(load_ms, 0.01),
		"save_bytes": FileAccess.get_file_as_bytes(svc.path_for("bench")).size(), "load_ok": lerr == "",
		"policies_enacted": enacted,
	}))
