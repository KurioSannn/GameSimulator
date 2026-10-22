extends RefCounted
## Generic standard every major historical case must meet (CASE-0001 is the reference).
## New cases inherit these checks automatically.

var t


func _j(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _cases() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		if f.ends_with(".json"):
			var c: Dictionary = _j("res://data/cases/" + f)
			out[c.case_id] = c
	return out


func _majors() -> Array:
	var cs := _cases()
	return cs.keys().filter(func(id): return cs[id].get("class") == "major_historical")


func _family(case_id: String) -> Dictionary:
	var cs := _cases()
	var out := {}
	for id in cs:
		if id == case_id or str(id).begins_with(case_id + "-"):
			out[id] = cs[id]
	return out


func test_every_major_case_meets_the_fact_fiction_standard() -> void:
	t.check(_majors().size() >= 2, "at least two major cases")
	for id in _majors():
		var c: Dictionary = _cases()[id]
		t.check(c.real_context.lines.size() >= 2, "%s: >= 2 real fact lines" % id)
		for line in c.real_context.lines:
			# ISO date at the precision the source gives: YYYY-MM-DD or YYYY-MM (never an invented day).
			var dated := RegEx.create_from_string("^\\d{4}-\\d{2}(-\\d{2})?$").search(str(line.as_of)) != null
			t.check(line.source_refs.size() >= 1 and dated, "%s: every real line has source + ISO date" % id)
		t.check(c.briefing.fact_class == "FICTIONAL", "%s: briefing FICTIONAL" % id)
		t.check(c.choices.size() >= 3, "%s: at least 3 decisions" % id)
		var sigs := {}
		for ch in c.choices:
			t.check(ch.fact_class == "SIMULATED", "%s/%s: SIMULATED" % [id, ch.choice_id])
			sigs[JSON.stringify([ch.effects, ch.get("enact_policy", {})])] = true  # enacted policy is part of the mechanics
		t.check(sigs.size() == c.choices.size(), "%s: no mechanically identical choices" % id)
		for fu in c.get("follow_ups", []):
			var f: Dictionary = _cases().get(fu, {})
			t.check(not f.is_empty(), "%s: follow-up %s exists" % [id, fu])
			t.check(f.get("origin_case", "") == id and f.real_context.lines.is_empty(), "%s: follow-up is a labeled simulated consequence" % fu)


func _session(cases: Dictionary, seed_value := 13) -> Session:
	return Session.new(_j("res://data/sim_params.json"), _j("res://data/regions.json").regions, _j("res://data/baseline.json"),
		cases, seed_value, _j("res://data/budget.json"))


func _play(case_id: String, choice: String) -> Session:
	var s := _session(_family(case_id))
	s.present_next_case()
	while not s.world.is_term_over():
		var pend := s.pending_case()
		if pend != "":
			s.decide(pend, choice if pend == case_id else "a")
		s.advance_quarter()
		s.present_next_case()
	return s


func test_every_major_case_choices_diverge_over_a_term() -> void:
	for id in _majors():
		var c: Dictionary = _cases()[id]
		var ends := {}
		for ch in c.choices:
			var s := _play(id, ch.choice_id)
			t.check(s.world.case_state.has(id), "%s triggers within the term" % id)
			var focus: Array = c.focus_regions.map(func(r): return s.world.region_index[r])
			var sig := ""
			for i in focus:
				sig += "%.3f|%.3f|%.3f;" % [s.world.get_v("damage", i), s.world.get_v("trust", i), s.world.get_v("services", i)]
			sig += "%.3f" % float(s.world.national.fiscal_space)
			ends[sig] = true
		t.check(ends.size() == c.choices.size(), "%s: every choice leads to a different end state" % id)


func test_decision_gate_for_every_major_case() -> void:
	for id in _majors():
		var s := _session(_family(id))
		while s.present_next_case() != id and not s.world.is_term_over():
			s.advance_quarter()
		t.check(s.pending_case() == id, "%s presented" % id)
		var tick := s.world.tick
		t.check(s.advance_quarter().is_empty() and s.world.tick == tick, "%s: time cannot advance while undecided" % id)
