extends RefCounted
## CASE-0005 (nickel downstreaming, Morowali + Halmahera Tengah) regression + golden master.
## Checks: documented-only geography, real trade-offs (no dominant choice), delayed structural effects,
## condition-driven follow-ups, attribution, determinism.

var t
const GOLDEN := "res://tests/golden/case0005.json"
const MOROWALI := "72.06"
const HALTENG := "82.02"
const DIRECT := [MOROWALI, HALTENG]


func _j(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _cases() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		if f.ends_with(".json") and f.begins_with("CASE-0005"):
			var c: Dictionary = _j("res://data/cases/" + f)
			out[c.case_id] = c
	return out


func _session(seed_value := 11) -> Session:
	return Session.new(_j("res://data/sim_params.json"), _j("res://data/regions.json").regions,
		_j("res://data/baseline.json"), _cases(), seed_value, _j("res://data/budget.json"))


func _decided(choice: String, seed_value := 11) -> Session:
	var s := _session(seed_value)
	while s.present_next_case() != "CASE-0005" and not s.world.is_term_over():
		s.advance_quarter()
	t.check(s.decide("CASE-0005", choice) == "", "decide %s" % choice)
	return s


## Plays `quarters` more quarters, answering follow-ups with `follow`. Returns presented ids.
func _run(s: Session, quarters: int, follow := "a") -> Array:
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


func _m(s: Session, v: String) -> float:
	var acc := 0.0
	for id in DIRECT:
		acc += s.world.get_v(v, s.world.region_index[id])
	return acc / DIRECT.size()


func test_presented_in_month_31_and_gated() -> void:
	var s := _session()
	while s.present_next_case() != "CASE-0005" and not s.world.is_term_over():
		s.advance_quarter()
	t.check(s.world.tick == 30, "presented at month index 30 (got %d)" % s.world.tick)
	t.check(s.advance_quarter().is_empty(), "no time advance while undecided")


func test_direct_effects_only_in_documented_estate_regencies() -> void:
	for ch in ["a", "b", "c"]:
		var s := _decided(ch)
		s.advance_quarter()
		s.advance_quarter()
		s.advance_quarter()
		var w := s.world
		for v in w.ledger.causes:
			for c in w.ledger.causes[v]:
				if not str(c).begins_with("eff:case:CASE-0005"):
					continue
				var arr: PackedFloat64Array = w.ledger.causes[v][c]
				for i in arr.size():
					if arr[i] != 0.0 and not (w.region_ids[i] in DIRECT):
						t.check(false, "%s: %s from %s reached %s" % [ch, v, c, w.region_ids[i]])
						return
	t.check(true, "no CASE-0005 effect outside Morowali and Halmahera Tengah")


func test_choices_are_real_trade_offs() -> void:
	var r := {}
	for ch in ["a", "b", "c"]:
		var s := _decided(ch)
		_run(s, 6, "c")  # follow-ups answered with the 'do little' option so the main choice dominates
		r[ch] = {"wb": _m(s, "welfare_base"), "env": _m(s, "environment"), "trust": _m(s, "trust"),
			"svc": _m(s, "services"), "fs": float(s.world.national.fiscal_space)}
	t.check(r.a.wb > r.b.wb and r.b.wb > r.c.wb, "structural income: accelerate > conditional > moratorium")
	t.check(r.a.env < r.b.env and r.b.env < r.c.env, "environment pressure in the reverse order")
	t.check(r.b.svc > r.a.svc and r.b.svc > r.c.svc, "only the conditional path builds inspection/health capacity")
	t.check(r.a.trust < r.b.trust and r.a.trust < r.c.trust, "accelerating after the explosion costs local trust")
	t.check(r.a.fs > r.b.fs and r.a.fs > r.c.fs, "national revenue: accelerating ends highest")
	var b1 := _decided("b")
	var c1 := _decided("c")
	b1.advance_quarter()
	c1.advance_quarter()
	t.check(float(b1.world.national.fiscal_space) < float(c1.world.national.fiscal_space), "the conditional path pays for enforcement up front")
	for ch in r:
		var best := 0
		for k in r[ch]:
			var top := true
			for other in r:
				if other != ch and r[other][k] > r[ch][k]:  # higher is better on every dimension here
					top = false
			if top:
				best += 1
		t.check(best < r[ch].size(), "choice %s is not best on every dimension" % ch)


func test_structural_income_is_delayed_and_attributed() -> void:
	var s := _decided("a")
	s.advance_quarter()
	var i: int = s.world.region_index[MOROWALI]
	var wb: Dictionary = s.world.ledger.causes.get("welfare_base", {})
	t.check(not wb.has("eff:case:CASE-0005/choice:a#delayed"), "no structural income in the first quarter (delay 6)")
	t.check((s.world.ledger.causes.trust["eff:case:CASE-0005/trigger#now"] as PackedFloat64Array)[i] == -2.0, "explosion aftermath attributed to the case event in Morowali")
	s.advance_quarter()
	s.advance_quarter()
	wb = s.world.ledger.causes.get("welfare_base", {})
	t.check(wb.has("eff:case:CASE-0005/choice:a#delayed") and (wb["eff:case:CASE-0005/choice:a#delayed"] as PackedFloat64Array)[i] == 3.0,
		"structural income +3 arrives as a delayed effect")
	var env: Dictionary = s.world.ledger.causes.environment
	t.check(env.has("eff:case:CASE-0005/choice:a#ongoing"), "environmental pressure is an ongoing monthly effect")


func test_follow_ups_only_when_their_conditions_hold() -> void:
	var a := _decided("a")
	var seen_a := _run(a, 5)
	t.check("CASE-0005-A" in seen_a, "accelerating leads to the Weda river follow-up (seen %s)" % str(seen_a))
	t.check(a.world.case_state["CASE-0005-A"].triggered_tick >= 39, "not before month index 39")
	var b := _decided("b")
	t.check(not ("CASE-0005-A" in _run(b, 8)), "conditional path keeps Halmahera Tengah environment above the trigger")
	t.check(b.world.vars.environment[b.world.region_index[HALTENG]] >= 46.0, "environment stays >= 46 under b")
	var c := _decided("c")
	var seen_c := _run(c, 3)
	t.check(seen_c == ["CASE-0005-C"] and c.world.case_state["CASE-0005-C"].triggered_tick == 36, "moratorium follow-up six months later")


func test_golden_master() -> void:
	var result := {}
	for ch in ["a", "b", "c"]:
		var s := _decided(ch)
		var presented := _run(s, (SimWorld.TERM_TICKS - s.world.tick) / SimWorld.TICKS_PER_QUARTER, "a")
		var end := {"fiscal_space": snappedf(float(s.world.national.fiscal_space), 0.0001),
			"national_welfare": snappedf(s.world.national_mean("welfare"), 0.0001),
			"national_sentiment": snappedf(s.world.national_mean("sentiment"), 0.0001)}
		for id in DIRECT:
			var i: int = s.world.region_index[id]
			for v in ["welfare_base", "welfare", "environment", "trust", "services", "sentiment"]:
				end["%s_%s" % [id, v]] = snappedf(s.world.get_v(v, i), 0.0001)
		result[ch] = {"presented": presented, "end": end}
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
