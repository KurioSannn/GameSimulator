extends RefCounted
## CASE-0006 (NTT drought 2023, Sabu Raijua + Kab. Kupang) regression + golden master.
## Checks: documented-only geography, exposure ordering, distinct relief strategies, next dry season
## scaled by water infrastructure, determinism.

var t
const GOLDEN := "res://tests/golden/case0006.json"
const SABU := "53.20"
const KUPANG := "53.01"
const DIRECT := [SABU, KUPANG]


func _j(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _session(seed_value := 11) -> Session:
	var cases := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		if f.ends_with(".json") and f.begins_with("CASE-0006"):
			var c: Dictionary = _j("res://data/cases/" + f)
			cases[c.case_id] = c
	return Session.new(_j("res://data/sim_params.json"), _j("res://data/regions.json").regions,
		_j("res://data/baseline.json"), cases, seed_value, _j("res://data/budget.json"))


func _decided(choice: String) -> Session:
	var s := _session()
	while s.present_next_case() != "CASE-0006" and not s.world.is_term_over():
		s.advance_quarter()
	t.check(s.decide("CASE-0006", choice) == "", "decide %s" % choice)
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


func _v(s: Session, v: String, id: String) -> float:
	return s.world.get_v(v, s.world.region_index[id])


func test_presented_in_september_of_year_one() -> void:
	var s := _session()
	while s.present_next_case() != "CASE-0006" and not s.world.is_term_over():
		s.advance_quarter()
	t.check(s.world.tick == 9 and s.world.month() == 10, "presented in October of year one (got tick %d, month %d)" % [s.world.tick, s.world.month()])
	t.check(s.advance_quarter().is_empty(), "no time advance while undecided")


func test_exposure_follows_documented_victims_and_stays_local() -> void:
	var s := _decided("a")
	s.advance_quarter()
	var w := s.world
	var tw: Dictionary = w.ledger.causes.welfare
	var key := "eff:case:CASE-0006/trigger#now"
	t.check((tw[key] as PackedFloat64Array)[w.region_index[SABU]] < (tw[key] as PackedFloat64Array)[w.region_index[KUPANG]], "Sabu Raijua (31,020 victims) hit harder than Kab. Kupang (1,044)")
	for v in w.ledger.causes:
		for c in w.ledger.causes[v]:
			if str(c).begins_with("eff:case:CASE-0006"):
				var arr: PackedFloat64Array = w.ledger.causes[v][c]
				for i in arr.size():
					if arr[i] != 0.0 and not (w.region_ids[i] in DIRECT):
						t.check(false, "%s reached %s" % [c, w.region_ids[i]])
						return
	t.check(true, "no CASE-0006 effect outside Sabu Raijua and Kab. Kupang (incl. Belu, Rote Ndao, Alor, SBD)")


func test_strategies_differ_in_what_they_fix() -> void:
	var r := {}
	for ch in ["a", "b", "c"]:
		var s := _decided(ch)
		s.advance_quarter()
		r[ch] = {"svc": _v(s, "services", SABU), "wel": _v(s, "welfare", SABU), "infra": _v(s, "infrastructure", SABU),
			"fs": float(s.world.national.fiscal_space)}
		_run(s, 3, "c")
		r[ch]["infra_later"] = _v(s, "infrastructure", SABU)
	t.check(r.a.svc > r.b.svc and r.a.svc > r.c.svc, "emergency water restores water services fastest")
	t.check(r.b.wel > r.a.wel and r.b.wel > r.c.wel, "livelihood support protects welfare most")
	t.check(r.c.infra == r.a.infra and r.c.infra_later > r.a.infra_later + 9.0, "water investment arrives only after 9 months (+10)")
	t.check(r.a.fs > r.b.fs and r.b.fs > r.c.fs, "fiscal cost a < b < c")


func test_next_dry_season_is_milder_where_water_was_built() -> void:
	var hit := {}
	for ch in ["a", "c"]:
		var s := _decided(ch)
		var seen := _run(s, 4, "c")
		t.check("CASE-0006-R" in seen, "%s: next dry season follow-up (seen %s)" % [ch, str(seen)])
		var st: Dictionary = s.world.case_state["CASE-0006-R"]
		t.check(int(st.triggered_tick) == 21, "R opens in the next October (tick 21), got %d" % int(st.triggered_tick))
		s.decide("CASE-0006-R", "c")
		s.advance_quarter()
		hit[ch] = (s.world.ledger.causes.welfare["eff:case:CASE-0006-R/trigger#now"] as PackedFloat64Array)[s.world.region_index[SABU]]
	t.check(hit.c > hit.a, "welfare hit smaller after water investment (a %.2f, c %.2f)" % [hit.a, hit.c])


func test_golden_master() -> void:
	var result := {}
	for ch in ["a", "b", "c"]:
		var s := _decided(ch)
		var presented := _run(s, (SimWorld.TERM_TICKS - s.world.tick) / SimWorld.TICKS_PER_QUARTER, "a")
		var end := {"fiscal_space": snappedf(float(s.world.national.fiscal_space), 0.0001),
			"national_welfare": snappedf(s.world.national_mean("welfare"), 0.0001)}
		for id in DIRECT:
			for v in ["welfare", "services", "infrastructure", "trust", "sentiment"]:
				end["%s_%s" % [id, v]] = snappedf(_v(s, v, id), 0.0001)
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
