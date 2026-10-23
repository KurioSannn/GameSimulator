extends RefCounted
## CASE-0007 (primary healthcare access, Papua Pegunungan + Papua Tengah) regression + golden master.
## Checks: documented provincial gap applied as a labeled data adjustment, province-only reach,
## distinct strategies, condition/time-driven follow-ups, determinism.

var t
const GOLDEN := "res://tests/golden/case0007.json"
const JAYAWIJAYA := "95.01"
const NABIRE := "94.01"


func _j(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _session(seed_value := 11) -> Session:
	var cases := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		if f.ends_with(".json") and f.begins_with("CASE-0007"):
			var c: Dictionary = _j("res://data/cases/" + f)
			cases[c.case_id] = c
	return Session.new(_j("res://data/sim_params.json"), _j("res://data/regions.json").regions,
		_j("res://data/baseline.json"), cases, seed_value, _j("res://data/budget.json"))


func _decided(choice: String) -> Session:
	var s := _session()
	while s.present_next_case() != "CASE-0007" and not s.world.is_term_over():
		s.advance_quarter()
	t.check(s.decide("CASE-0007", choice) == "", "decide %s" % choice)
	return s


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


func _pm(s: Session, v: String, prov: String) -> float:
	var idx := EffectQueue.resolve_scope(s.world, "province:" + prov)
	var acc := 0.0
	for i in idx:
		acc += s.world.get_v(v, i)
	return acc / idx.size()


func test_presented_and_gated() -> void:
	var s := _session()
	while s.present_next_case() != "CASE-0007" and not s.world.is_term_over():
		s.advance_quarter()
	t.check(s.world.tick == 15, "presented at tick 15 (got %d)" % s.world.tick)
	t.check(s.advance_quarter().is_empty(), "no time advance while undecided")
	t.check(str(s.cases.cases["CASE-0007"].get("trigger_label", "")).begins_with("Penyesuaian data"), "opening effects labeled as a data adjustment, not an event")


func test_documented_gap_applied_only_to_the_two_provinces() -> void:
	var s := _decided("a")
	s.advance_quarter()
	var w := s.world
	var adj: PackedFloat64Array = w.ledger.causes.services["eff:case:CASE-0007/trigger#now"]
	t.near(adj[w.region_index[JAYAWIJAYA]], -10.9, 1e-9, "Papua Pegunungan: -0.2 x 54.3")
	t.near(adj[w.region_index[NABIRE]], -8.7, 1e-9, "Papua Tengah: -0.2 x 43.5")
	for v in w.ledger.causes:
		for c in w.ledger.causes[v]:
			if str(c).begins_with("eff:case:CASE-0007"):
				var arr: PackedFloat64Array = w.ledger.causes[v][c]
				for i in arr.size():
					var p := w.region_ids[i].substr(0, 2)
					if arr[i] != 0.0 and p != "95" and p != "94":
						t.check(false, "%s reached %s" % [c, w.region_ids[i]])
						return
	t.check(true, "no CASE-0007 effect outside Papua Pegunungan and Papua Tengah (Papua Barat Daya etc. untouched)")


func test_strategies_trade_speed_reach_and_cost() -> void:
	var r := {}
	for ch in ["a", "b", "c"]:
		var s := _decided(ch)
		s.advance_quarter()
		r[ch] = {"svc95_q1": _pm(s, "services", "95"), "fs_q1": float(s.world.national.fiscal_space)}
		_run(s, 4, "c")
		r[ch]["svc95"] = _pm(s, "services", "95")
		r[ch]["svc94"] = _pm(s, "services", "94")
		r[ch]["infra95"] = _pm(s, "infrastructure", "95")
		r[ch]["fs"] = float(s.world.national.fiscal_space)
	t.check(r.c.svc95_q1 > r.b.svc95_q1 and r.b.svc95_q1 > r.a.svc95_q1, "first quarter: outreach > central teams > regional capacity")
	t.check(r.b.svc94 > r.a.svc94 and r.a.svc94 > r.c.svc94, "Papua Tengah: central teams best, outreach does not reach it")
	t.check(r.c.infra95 > r.a.infra95 + 5.0 and r.c.infra95 > r.b.infra95 + 5.0, "only outreach/referral builds access infrastructure")
	t.check(r.a.fs_q1 > r.b.fs_q1 and r.b.fs_q1 > r.c.fs_q1, "upfront cost: a < b < c")
	t.check(r.a.fs > r.b.fs, "central teams cost more over time")


func test_follow_ups_follow_their_conditions() -> void:
	var a := _decided("a")
	var seen_a := _run(a, 4)
	t.check("CASE-0007-A" in seen_a and int(a.world.case_state["CASE-0007-A"].triggered_tick) == 24, "slow regional path -> recruitment follow-up at tick 24 (seen %s)" % str(seen_a))
	var c := _decided("c")
	t.check(not ("CASE-0007-A" in _run(c, 6)) and not c.world.case_state.has("CASE-0007-B"), "outreach path triggers neither follow-up")
	var b := _decided("b")
	var seen_b := _run(b, 10)
	t.check("CASE-0007-B" in seen_b and int(b.world.case_state["CASE-0007-B"].triggered_tick) == 42, "central teams -> end-of-deployment follow-up at tick 42 (seen %s)" % str(seen_b))


func test_golden_master() -> void:
	var result := {}
	for ch in ["a", "b", "c"]:
		var s := _decided(ch)
		var presented := _run(s, (SimWorld.TERM_TICKS - s.world.tick) / SimWorld.TICKS_PER_QUARTER, "a")
		var end := {"fiscal_space": snappedf(float(s.world.national.fiscal_space), 0.0001),
			"national_welfare": snappedf(s.world.national_mean("welfare"), 0.0001)}
		for prov in ["95", "94"]:
			for v in ["services", "infrastructure", "welfare", "trust", "sentiment"]:
				end["%s_%s" % [prov, v]] = snappedf(_pm(s, v, prov), 0.0001)
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
