extends RefCounted

var t


func _setup() -> Array:
	var params: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sim_params.json"))
	var regions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))["regions"]
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/baseline.json"))
	var case: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cases/CASE-0001.json"))
	var sim := Simulation.new(params, JSON.parse_string(FileAccess.get_file_as_string("res://data/budget.json")))
	var w := WorldFactory.build(regions, baseline, sim, 3)
	# Hazard-free world: these tests check case scoping/branching, not background floods.
	var f: PackedFloat64Array = w.vars["flood_frequency"]
	f.fill(0.0)
	w.vars["flood_frequency"] = f
	return [sim, w, CaseEngine.new({"CASE-0001": case})]


func _run_choice(choice: String) -> SimWorld:
	var p := _setup()
	var sim: Simulation = p[0]
	var w: SimWorld = p[1]
	var eng: CaseEngine = p[2]
	var id := eng.pick(w, eng.eligible(w))
	t.check(id == "CASE-0001", "case should be eligible at start")
	eng.trigger(w, id)
	t.check(eng.decide(w, id, choice) == "", "decide ok")
	for _i in 12:
		sim.step_month(w)
	return w


func test_choices_diverge_and_have_tradeoffs() -> void:
	var a := _run_choice("a")
	var b := _run_choice("b")
	var c := _run_choice("c")
	var jp: int = a.region_index["31.71"]
	t.check(a.national.fiscal_space < b.national.fiscal_space, "central response costs more than regional")
	t.check(a.get_v("damage", jp) < b.get_v("damage", jp), "central response recovers faster")
	t.check(c.get_v("infrastructure", jp) > a.get_v("infrastructure", jp), "infrastructure choice builds capacity")
	t.check(c.get_v("trust", jp) < a.get_v("trust", jp), "infrastructure choice costs short-term trust")
	t.check(a.memory.flood2020_response == "central" and c.memory.flood2020_response == "infrastructure", "memory flags")


func test_case_triggers_once_and_conditions() -> void:
	var p := _setup()
	var w: SimWorld = p[1]
	var eng: CaseEngine = p[2]
	eng.trigger(w, "CASE-0001")
	t.check(eng.eligible(w).is_empty(), "not eligible again after trigger")
	t.check(eng.active_cases(w) == ["CASE-0001"], "active list")
	t.check(eng.decide(w, "CASE-0001", "zzz") != "", "invalid choice rejected")
	t.check(eng.eval_condition(w, {"var": "damage", "scope": "province:31", "agg": "max", "op": ">=", "value": 0}), "var cond")
	t.check(not eng.eval_condition(w, {"memory": "nope"}), "missing memory is false")
	t.check(eng.eval_condition(w, {"any": [{"case_seen": "CASE-0001"}, {"tick": ">", "value": 99}]}), "any")


func test_unaffected_region_not_directly_hit() -> void:
	var w := _run_choice("a")
	var papua: int = w.region_index["91.71"]  # Kota Jayapura
	t.near(w.get_v("damage", papua), 0.0, 0.0001, "no direct damage outside case scope")
