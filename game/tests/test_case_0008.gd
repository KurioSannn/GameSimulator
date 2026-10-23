extends RefCounted
## CASE-0008 (fuel subsidy reform, Sep 2022) regression + golden master.
## Checks: national fiscal trade-off, fuel price vs household support attributed separately, temporary
## support expires on schedule, phased second step, explicit additive interaction with CASE-0003's
## price pressure (D-074), condition-driven follow-ups, save/load of pending consequences.

var t
const GOLDEN := "res://tests/golden/case0008.json"


func _j(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _session(families: Array = ["CASE-0008"], seed_value := 11) -> Session:
	var cases := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		for fam in families:
			if f.ends_with(".json") and f.begins_with(fam):
				var c: Dictionary = _j("res://data/cases/" + f)
				cases[c.case_id] = c
	return Session.new(_j("res://data/sim_params.json"), _j("res://data/regions.json").regions,
		_j("res://data/baseline.json"), cases, seed_value, _j("res://data/budget.json"))


func _decided(choice: String) -> Session:
	var s := _session()
	while s.present_next_case() != "CASE-0008" and not s.world.is_term_over():
		s.advance_quarter()
	t.check(s.decide("CASE-0008", choice) == "", "decide %s" % choice)
	return s


func _run(s: Session, quarters: int, follow := "c") -> Array:
	var seen: Array = []
	for _q in quarters:
		var pend := s.pending_case()
		if pend != "":
			seen.append(pend)
			s.decide(pend, follow)
		s.advance_quarter()
		s.present_next_case()
	if s.pending_case() != "":
		seen.append(s.pending_case())
	return seen


func _exact(s: Session, v: String) -> float:
	var w := s.world
	var worst := 0.0
	for i in w.region_count():
		var sum := 0.0
		for c in w.ledger.causes.get(v, {}):
			sum += (w.ledger.causes[v][c] as PackedFloat64Array)[i]
		worst = maxf(worst, absf(sum - (w.vars[v][i] - w.ledger.start[v][i])))
	return worst


func test_presented_at_tick_33_and_gated() -> void:
	var s := _session()
	while s.present_next_case() != "CASE-0008" and not s.world.is_term_over():
		s.advance_quarter()
	t.check(s.world.tick == 33, "presented at tick 33 (got %d)" % s.world.tick)
	t.check(s.advance_quarter().is_empty(), "no time advance while undecided")


func test_fiscal_trade_off_is_national_and_explained() -> void:
	var fs := {}
	for ch in ["a", "b", "c"]:
		var s := _decided(ch)
		s.advance_quarter()
		t.check(s.world.ledger.national_causes.fiscal_space.keys().any(func(k): return str(k).begins_with("eff:case:CASE-0008/choice:" + ch)), "%s: fiscal change attributed to the decision" % ch)
		_run(s, 3)
		fs[ch] = float(s.world.national.fiscal_space)
	t.check(fs.b > fs.c and fs.c > fs.a, "after a year: targeted adjustment frees most budget, holding prices drains it (a %.1f, b %.1f, c %.1f)" % [fs.a, fs.b, fs.c])


func test_fuel_price_and_household_support_are_separate_causes() -> void:
	var s := _decided("b")
	s.advance_quarter()
	var w := s.world
	var price_src: PackedFloat64Array = w.ledger.causes.price_level["drv:price_pressure|case:CASE-0008/choice:b"]
	var support: PackedFloat64Array = w.ledger.causes.welfare["eff:case:CASE-0008/choice:b#now"]
	var low_price := 0
	var all_support := true
	for i in w.region_count():
		if price_src[i] <= 0.0:
			low_price += 1
		if support[i] <= 0.0:
			all_support = false
	t.check(low_price == 0, "fuel adjustment raises the price level in all 514 regions via the national driver")
	t.check(all_support, "household support recorded as its own welfare cause in every region")
	t.check(_exact(s, "price_level") < 1e-9 and _exact(s, "welfare") < 1e-9, "causes sum exactly")


func test_temporary_support_expires_on_schedule() -> void:
	var s := _decided("b")
	s.advance_quarter()
	s.advance_quarter()  # months 34-39: BLT (4 months) has ended inside this quarter
	s.advance_quarter()
	var w := s.world
	for c in w.ledger.causes.get("welfare", {}):
		t.check(not str(c).begins_with("eff:case:CASE-0008/choice:b"), "no BLT/BSU welfare effect after expiry (%s)" % c)
	for e in w.pending_effects:
		t.check(not (str(e.source) == "case:CASE-0008/choice:b" and str(e.var) == "welfare"), "no pending BLT effect left")
	var c8 := _decided("c")
	c8.advance_quarter()
	c8.advance_quarter()
	c8.advance_quarter()
	t.check(c8.world.ledger.national_causes.price_pressure.has("eff:case:CASE-0008/choice:c#delayed"), "phased second price step arrives after 6 months")


func test_interaction_with_cooking_oil_pressure_is_additive_and_attributed() -> void:
	var s := _session(["CASE-0008", "CASE-0003"])
	while not (s.world.case_state.has("CASE-0003") and s.world.case_state.has("CASE-0008")) and not s.world.is_term_over():
		var p := s.present_next_case()
		if p != "":
			s.decide(p, "b")
		s.advance_quarter()
	t.check(s.world.case_state.has("CASE-0003") and s.world.case_state.has("CASE-0008"), "both cases played")
	s.advance_quarter()
	var keys: Array = s.world.ledger.causes.price_level.keys()
	t.check(keys.has("drv:price_pressure|case:CASE-0008/choice:b"), "fuel share attributed")
	t.check(keys.has("drv:price_pressure|case:CASE-0003/trigger"), "cooking-oil shock attributed separately")
	t.check(_exact(s, "price_level") < 1e-9, "combined pressure still sums exactly per region")
	var shares: Dictionary = s.world.drivers.price_pressure
	var total := 0.0
	for k in shares:
		total += float(shares[k])
	t.near(total, float(s.world.national.price_pressure), 1e-12, "driver shares add up to the single national value")


func test_follow_ups_follow_their_conditions() -> void:
	var a := _decided("a")
	var seen_a := _run(a, 3)
	t.check("CASE-0008-A" in seen_a, "holding prices drains fiscal space -> subsidy-budget follow-up at tick 36 (seen %s)" % str(seen_a))
	var b := _decided("b")
	var seen_b := _run(b, 3)
	t.check("CASE-0008-B" in seen_b, "BLT about to end while prices are still above 101 -> follow-up at tick 36 (seen %s)" % str(seen_b))
	var c := _decided("c")
	var seen_c := _run(c, 3)
	t.check(not ("CASE-0008-A" in seen_c) and not ("CASE-0008-B" in seen_c), "phased path triggers neither")


func test_pending_consequences_survive_save_and_load() -> void:
	var s := _decided("b")
	s.advance_quarter()
	var saved := JSON.stringify(s.world.to_dict())
	var r := _session()
	t.check(r.world.load_dict(JSON.parse_string(saved)) == "", "load ok")
	t.check(r.world.pending_effects.size() == s.world.pending_effects.size(), "pending subsidy savings and BLT months restored")
	_run(s, 2)
	_run(r, 2)
	t.check(s.world.national.fiscal_space == r.world.national.fiscal_space and s.world.vars.welfare == r.world.vars.welfare, "identical future after reload")


func test_golden_master() -> void:
	var result := {}
	for ch in ["a", "b", "c"]:
		var s := _decided(ch)
		var presented := _run(s, (SimWorld.TERM_TICKS - s.world.tick) / SimWorld.TICKS_PER_QUARTER, "a")
		result[ch] = {"presented": presented, "end": {
			"fiscal_space": snappedf(float(s.world.national.fiscal_space), 0.0001),
			"price_pressure": snappedf(float(s.world.national.price_pressure), 0.000001),
			"national_price": snappedf(s.world.national_mean("price_level"), 0.0001),
			"national_welfare": snappedf(s.world.national_mean("welfare"), 0.0001),
			"national_sentiment": snappedf(s.world.national_mean("sentiment"), 0.0001),
			"national_trust": snappedf(s.world.national_mean("trust"), 0.0001),
			"national_services": snappedf(s.world.national_mean("services"), 0.0001)}}
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
