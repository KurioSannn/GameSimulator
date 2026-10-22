extends RefCounted
## CASE-0002 (Palu–Sigi–Donggala 2018) specific regression + golden master.

var t
const GOLDEN := "res://tests/golden/case0002.json"
const PALU := "72.71"
const SIGI := "72.10"
const DGL := "72.03"
const PM := "72.08"


func _j(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _cases(prefix := "CASE-0002") -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		if f.ends_with(".json") and f.begins_with(prefix):
			var c: Dictionary = _j("res://data/cases/" + f)
			out[c.case_id] = c
	return out


func _session(cases: Dictionary, seed_value := 11) -> Session:
	return Session.new(_j("res://data/sim_params.json"), _j("res://data/regions.json").regions, _j("res://data/baseline.json"),
		cases, seed_value, _j("res://data/budget.json"))


func _to_case(s: Session) -> void:
	while s.present_next_case() != "CASE-0002" and not s.world.is_term_over():
		s.advance_quarter()


func test_triggers_in_second_year_with_proportional_shock() -> void:
	var s := _session(_cases())
	_to_case(s)
	t.check(s.world.tick == 21, "presented at the first quarter boundary after month 20 (got %d)" % s.world.tick)
	var before := {}
	for r in [PALU, SIGI, DGL, PM]:
		before[r] = s.world.get_v("damage", s.world.region_index[r])
	s.decide("CASE-0002", "a")
	s.sim.step_month(s.world)
	var d := func(r): return s.world.get_v("damage", s.world.region_index[r]) - before[r]
	t.check(d.call(PALU) > d.call(SIGI) and d.call(SIGI) > d.call(DGL) and d.call(DGL) > d.call(PM), "shock ordered by BNPB loss shares")


func test_relocation_trust_dips_then_recovers_and_builds_services() -> void:
	var s := _session(_cases())
	_to_case(s)
	var i: int = s.world.region_index[PALU]
	var trust0 := s.world.get_v("trust", i)
	var serv0 := s.world.get_v("services", i)
	s.decide("CASE-0002", "b")
	s.sim.step_month(s.world)
	t.check(s.world.get_v("trust", i) < trust0, "relocation: trust dips immediately")
	for _m in 12:
		s.sim.step_month(s.world)
	t.check(s.world.get_v("services", i) > serv0 + 2.0, "permanent settlements bring services after 12 months")
	t.check(s.world.memory.get("palu2018_red_zone_cleared", false), "long-term risk reduction recorded as memory (not an in-term bonus)")


func test_rebuild_in_place_is_fastest_but_keeps_residual_risk() -> void:
	var a := _session(_cases())
	var b := _session(_cases())
	for pair in [[a, "a"], [b, "b"]]:
		_to_case(pair[0])
		pair[0].decide("CASE-0002", pair[1])
		for _m in 4:
			pair[0].sim.step_month(pair[0].world)
	var i: int = a.world.region_index[PALU]
	t.check(a.world.get_v("damage", i) < b.world.get_v("damage", i), "rebuild in place recovers faster in the first months")
	t.check(a.world.memory.get("palu2018_red_zone_residual_risk", false), "residual risk recorded")
	t.check(float(a.world.national.fiscal_space) > float(b.world.national.fiscal_space), "relocation costs more")


func test_follow_ups_branch_by_choice_and_state() -> void:
	var c := _session(_cases())
	_to_case(c)
	c.decide("CASE-0002", "c")
	var seen := []
	while not c.world.is_term_over():
		var p := c.pending_case()
		if p != "":
			seen.append(p)
			c.decide(p, "a")
		c.advance_quarter()
		c.present_next_case()
	t.check("CASE-0002-C" in seen and not ("CASE-0002-B" in seen), "stimulus path opens the building-quality follow-up only: %s" % str(seen))
	# Natural relocation path: trust stays low after the shock -> the follow-up opens.
	var n := _session(_cases())
	_to_case(n)
	n.decide("CASE-0002", "b")
	var seen_n := []
	while not n.world.is_term_over():
		var p := n.pending_case()
		if p != "":
			seen_n.append(p)
			n.decide(p, "a")
		n.advance_quarter()
		n.present_next_case()
	t.check("CASE-0002-B" in seen_n, "low-trust relocation path opens the return-to-red-zone follow-up: %s" % str(seen_n))
	# Same path with trust held high (explicit test fixture, set every month) -> it stays closed.
	var b := _session(_cases())
	_to_case(b)
	b.decide("CASE-0002", "b")
	EffectQueue.schedule(b.world, [{"scope": "regions:%s,%s" % [PALU, SIGI], "var": "trust", "op": "set", "value": 70.0, "delay": 1, "duration": 40}], "test:high_trust")
	var seen_b := []
	while not b.world.is_term_over():
		var p := b.pending_case()
		if p != "":
			seen_b.append(p)
			b.decide(p, "a")
		b.advance_quarter()
		b.present_next_case()
	t.check(not ("CASE-0002-B" in seen_b), "return-to-red-zone follow-up stays closed when trust is high: %s" % str(seen_b))


func test_both_cases_in_one_run_and_save_load() -> void:
	var all := _cases("CASE-000")
	var s := _session(all)
	var seen := []
	s.present_next_case()
	for _q in 10:
		var p := s.pending_case()
		if p != "":
			seen.append([p, s.world.tick])
			s.decide(p, "b")
		s.advance_quarter()
		s.present_next_case()
	t.check(seen[0][0] == "CASE-0001" and seen.any(func(x): return x[0] == "CASE-0002"), "CASE-0001 opens, CASE-0002 follows: %s" % str(seen))
	var svc := SaveService.new("user://test_saves_case0002")
	svc.save("x", "x", s.world.to_dict())
	var q := _session(all)
	t.check(q.world.load_dict(svc.load_slot("x").payload) == "", "load")
	for z in [s, q]:
		while not z.world.is_term_over():
			var p: String = z.pending_case()
			if p != "":
				z.decide(p, "c")
			z.advance_quarter()
			z.present_next_case()
	t.check(s.world.vars["damage"] == q.world.vars["damage"] and s.world.case_state == q.world.case_state, "identical after reload with two case families")


func test_golden_master() -> void:
	var result := {}
	for ch in ["a", "b", "c"]:
		var s := _session(_cases())
		s.present_next_case()
		var seq := []
		while not s.world.is_term_over():
			var p := s.pending_case()
			if p != "":
				seq.append(p)
				s.decide(p, ch if p == "CASE-0002" else "a")
			s.advance_quarter()
			s.present_next_case()
		var end := {}
		for r in [PALU, SIGI, DGL]:
			var i: int = s.world.region_index[r]
			end[r + "_damage"] = snappedf(s.world.get_v("damage", i), 0.0001)
			end[r + "_trust"] = snappedf(s.world.get_v("trust", i), 0.0001)
			end[r + "_services"] = snappedf(s.world.get_v("services", i), 0.0001)
		end["fiscal_space"] = snappedf(float(s.world.national.fiscal_space), 0.0001)
		result[ch] = {"presented": seq, "end": end}
	if OS.get_environment("NUSANTARA_UPDATE_GOLDEN") == "1":
		var f := FileAccess.open(GOLDEN, FileAccess.WRITE)
		f.store_string(JSON.stringify(result, "  ", true))
		f.close()
		print("    golden master updated: ", GOLDEN)
		return
	t.check(FileAccess.file_exists(GOLDEN), "golden exists")
	if not FileAccess.file_exists(GOLDEN):
		return
	var exp: Dictionary = _j(GOLDEN)
	for ch in result:
		t.check(result[ch].presented == exp[ch].presented, "choice %s: sequence changed" % ch)
		for k in result[ch].end:
			t.near(result[ch].end[k], float(exp[ch].end[k]), 0.0002, "choice %s: %s drifted" % [ch, k])
