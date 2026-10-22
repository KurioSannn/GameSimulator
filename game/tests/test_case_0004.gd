extends RefCounted
## CASE-0004 (2015 peat fires) + first local-wisdom mechanic (POL-KEBENCANAAN-API-ADAT / CULT-0001).
## Hazard-free worlds (no floods) isolate the fire mechanism.

var t
const GOLDEN := "res://tests/golden/case0004.json"


func _j(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _cases() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		if f.ends_with(".json") and f.begins_with("CASE-0004"):
			var c: Dictionary = _j("res://data/cases/" + f)
			out[c.case_id] = c
	return out


func _policies() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/policies"):
		if f.ends_with(".json"):
			var p: Dictionary = _j("res://data/policies/" + f)
			out[p.policy_id] = p
	return out


func _session(hazard_free := true, seed_value := 11) -> Session:
	var s := Session.new(_j("res://data/sim_params.json"), _j("res://data/regions.json").regions, _j("res://data/baseline.json"),
		_cases(), seed_value, _j("res://data/budget.json"), _policies())
	if hazard_free:
		var f: PackedFloat64Array = s.world.vars["flood_frequency"]
		f.fill(0.0)
		s.world.vars["flood_frequency"] = f
	return s


func _to(s: Session, case_id: String) -> void:
	while s.present_next_case() != case_id and not s.world.is_term_over():
		var p := s.pending_case()
		if p != "":
			s.decide(p, "a")
		s.advance_quarter()


func _pm(s: Session, v: String, prov: String) -> float:
	var idx := EffectQueue.resolve_scope(s.world, "province:" + prov)
	var acc := 0.0
	for i in idx:
		acc += s.world.get_v(v, i)
	return acc / idx.size()


func test_presented_in_october_of_year_four() -> void:
	var s := _session()
	_to(s, "CASE-0004")
	t.check(s.world.tick == 45 and s.world.month() == 10, "presented at month 45 (October) — got %d / month %d" % [s.world.tick, s.world.month()])


func test_choices_enact_the_right_policies() -> void:
	for pair in [["a", ""], ["b", "POL-KEBENCANAAN-RESTORASI-GAMBUT"], ["c", "POL-KEBENCANAAN-API-ADAT"]]:
		var s := _session()
		_to(s, "CASE-0004")
		t.check(s.decide("CASE-0004", pair[0]) == "", "decide %s" % pair[0])
		var active := s.policies.active_policies(s.world)
		if pair[1] == "":
			t.check(active.is_empty(), "ban enacts no policy")
		else:
			t.check(active == [pair[1]], "choice %s enacts %s (got %s)" % [pair[0], pair[1], str(active)])
			# Restoration: BRG priority province (all 14 kab/kota). Local wisdom: only where CULT-0001 documents
			# the practice (Kab. Kapuas, 62.03), never generalized to the province (CULT-0001 sensitivity review).
			var want := 14 if pair[1] == "POL-KEBENCANAAN-RESTORASI-GAMBUT" else 1
			t.check(int(s.world.policy_state[pair[1]].regions) == want, "%s targets %d kab/kota" % [pair[1], want])
			if want == 1:
				t.check(s.world.policy_state[pair[1]].target == {"type": "kabkota", "id": "62.03"}, "adat policy scoped to Kapuas")


func test_local_wisdom_policy_is_researched_and_ritual_excluded() -> void:
	var p: Dictionary = _policies()["POL-KEBENCANAAN-API-ADAT"]
	t.check(p.cultural_basis.culture_record_ref == "CULT-0001", "policy references the culture record")
	t.check(str(p.cultural_basis.interpretation).contains("Ritual elements are excluded"), "ritual excluded from the mechanic")
	t.check(p.fact_class == "FICTIONAL", "the mechanic is labeled a game abstraction")


func test_community_governance_effect_depends_on_trust() -> void:
	var outcomes := []
	for trust in [40.0, 70.0]:
		var s := _session()
		var f: PackedFloat64Array = s.world.vars["trust"]
		f.fill(trust)
		s.world.vars["trust"] = f
		s.enact_policy("POL-KEBENCANAAN-API-ADAT", {"type": "province", "id": "62"})
		for _m in 15:
			s.sim.step_month(s.world)
		outcomes.append(_pm(s, "fire_prevention", "62"))
	t.check(outcomes[1] > outcomes[0] * 1.5, "higher trust -> stronger community fire governance (%f vs %f)" % [outcomes[0], outcomes[1]])
	t.check(outcomes[0] > 0.0, "still works (weaker) when trust is low")


func _play(choice: String, follow := "c", hazard_free := true) -> Session:
	var s := _session(hazard_free)
	s.present_next_case()
	while not s.world.is_term_over():
		var p := s.pending_case()
		if p != "":
			s.decide(p, choice if p == "CASE-0004" else follow)
		s.advance_quarter()
		s.present_next_case()
	return s


func _seen(s: Session) -> Array:
	return s.world.case_state.keys()


func test_fire_season_follow_up_timing_and_prevention_payoff() -> void:
	var res := {}
	for ch in ["a", "b", "c"]:
		var s := _session()
		_to(s, "CASE-0004")
		s.decide("CASE-0004", ch)
		var before := {}
		while s.present_next_case() != "CASE-0004-R" and not s.world.is_term_over():
			var p := s.pending_case()
			if p != "":
				s.decide(p, "c")
			s.advance_quarter()
		t.check(s.world.tick == 54 and s.world.month() == 7, "%s: fire-season case at month 54 (July, start of the dry-season design calendar) — got %d" % [ch, s.world.tick])
		for prov in ["62", "14"]:
			before[prov] = _pm(s, "damage", prov)
		var prev := {"62": _pm(s, "fire_prevention", "62"), "14": _pm(s, "fire_prevention", "14")}
		s.decide("CASE-0004-R", "c")
		s.sim.step_month(s.world)  # episode (on_trigger) applies this month
		res[ch] = {"k_hit": _pm(s, "damage", "62") - before["62"], "r_hit": _pm(s, "damage", "14") - before["14"], "k_prev": prev["62"], "r_prev": prev["14"]}
	# Causal monotonicity: within the same episode, more prevention -> smaller impact.
	var order := ["a", "b", "c"]
	order.sort_custom(func(x, y): return res[x].k_prev < res[y].k_prev)
	t.check(res[order[0]].k_hit >= res[order[1]].k_hit and res[order[1]].k_hit >= res[order[2]].k_hit, "Kalteng impact decreases with prevention: %s" % str(res))
	# Explainable timing: restoration is still under construction at the first fire season (slower than the ban).
	t.check(res.a.k_prev > res.b.k_prev, "ban deters immediately; restoration still building at the first season")
	t.check(res.a.r_hit < res.b.r_hit and res.a.r_hit < res.c.r_hit, "regional asymmetry: only the nationwide ban protects Riau")


func test_ban_costs_livelihoods_where_documented() -> void:
	var a := _session()
	var c := _session()
	for pair in [[a, "a"], [c, "c"]]:
		_to(pair[0], "CASE-0004")
		pair[0].decide("CASE-0004", pair[1])
		for _m in 9:
			pair[0].sim.step_month(pair[0].world)
	t.check(_pm(a, "welfare", "62") < _pm(c, "welfare", "62"), "total ban lowers Kalteng welfare vs community governance")
	t.check(_pm(a, "trust", "62") < _pm(c, "trust", "62"), "and trust")
	t.near(_pm(a, "welfare", "14"), _pm(c, "welfare", "14"), 0.5, "no documented livelihood effect applied outside Kalteng")


func test_follow_ups_are_exclusive_and_state_dependent() -> void:
	var a := _seen(_play("a"))
	var b := _seen(_play("b"))
	t.check("CASE-0004-A" in a and not ("CASE-0004-C" in a), "ban path: livelihood follow-up, never the community follow-up: %s" % str(a))
	t.check(not ("CASE-0004-A" in b or "CASE-0004-C" in b), "restoration path opens neither A nor C: %s" % str(b))
	for k in [a, b]:
		t.check("CASE-0004-R" in k, "fire season returns on every path")
	# C opens only on the community path AND when trust is low in the dry season.
	var lo := _session()
	_to(lo, "CASE-0004")
	lo.decide("CASE-0004", "c")
	EffectQueue.schedule(lo.world, [{"scope": "province:62", "var": "trust", "op": "set", "value": 45.0, "delay": 1, "duration": 20}], "test:low_trust")
	while not lo.world.is_term_over():
		var p := lo.pending_case()
		if p != "":
			lo.decide(p, "c")
		lo.advance_quarter()
		lo.present_next_case()
	t.check("CASE-0004-C" in lo.world.case_state, "community path + low trust -> fire-spread follow-up")
	var hi := _session()
	_to(hi, "CASE-0004")
	hi.decide("CASE-0004", "c")
	EffectQueue.schedule(hi.world, [{"scope": "province:62", "var": "trust", "op": "set", "value": 65.0, "delay": 1, "duration": 20}], "test:high_trust")
	while not hi.world.is_term_over():
		var p := hi.pending_case()
		if p != "":
			hi.decide(p, "c")
		hi.advance_quarter()
		hi.present_next_case()
	t.check(not ("CASE-0004-C" in hi.world.case_state), "community path + high trust -> no fire-spread follow-up")


func test_golden_master() -> void:
	var result := {}
	for ch in ["a", "b", "c"]:
		var s := _play(ch, "c", false)
		var end := {}
		for prov in ["62", "14", "61"]:
			end[prov + "_damage"] = snappedf(_pm(s, "damage", prov), 0.0001)
			end[prov + "_welfare"] = snappedf(_pm(s, "welfare", prov), 0.0001)
			end[prov + "_trust"] = snappedf(_pm(s, "trust", prov), 0.0001)
			end[prov + "_fire_prevention"] = snappedf(_pm(s, "fire_prevention", prov), 0.0001)
		end["fiscal_space"] = snappedf(float(s.world.national.fiscal_space), 0.0001)
		end["national_sentiment"] = snappedf(s.world.national_mean("sentiment"), 0.0001)
		var seen := s.world.case_state.keys()
		seen.sort()
		result[ch] = {"presented": seen, "end": end}
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
		t.check(result[ch].presented == exp[ch].presented, "choice %s: case set changed" % ch)
		for k in result[ch].end:
			t.near(result[ch].end[k], float(exp[ch].end[k]), 0.0002, "choice %s: %s drifted" % [ch, k])
