extends RefCounted
## Gold-standard reference case regression suite (CASE-0001 + follow-ups).
## Verifies: real facts/attribution, fictional briefing, decisions, immediate/delayed/regional/
## national consequences, sentiment change, state-dependent branching, determinism, golden master.
##
## Golden master: game/tests/golden/case0001.json. If a deliberate model change alters results,
## regenerate with:  NUSANTARA_UPDATE_GOLDEN=1 Godot --headless --path game -s res://tests/run_tests.gd
## and record the reason in the commit message.

var t
const GOLDEN := "res://tests/golden/case0001.json"
const DKI := "31.71"
const BOGOR := "32.01"
const CONTROL := "51.71"  # Kota Denpasar: far from the case (has a small province-proxy flood rate)


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Only the CASE-0001 family: keeps this gold-standard suite (and its golden master) independent of
## other cases added later (e.g. CASE-0002 appearing in month 21).
func _all_cases() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		if f.ends_with(".json") and f.begins_with("CASE-0001"):
			var c: Dictionary = _json("res://data/cases/" + f)
			out[c.case_id] = c
	return out


func _session(seed_value := 11) -> Session:
	return Session.new(_json("res://data/sim_params.json"), _json("res://data/regions.json").regions,
		_json("res://data/baseline.json"), _all_cases(), seed_value, _json("res://data/budget.json"))


## Plays a full term choosing `first` for CASE-0001 and the first option for every other case.
## Returns {session, presented: [case ids in order], snapshots: {tick: {...}}}.
func _play(first: String, follow_choice := "a", seed_value := 11) -> Dictionary:
	var s := _session(seed_value)
	var presented: Array = []
	var snaps := {}
	var guard := 0
	s.present_next_case()
	while not s.world.is_term_over() and guard < 200:
		guard += 1
		var pend := s.pending_case()
		if pend != "":
			presented.append(pend)
			t.check(s.decide(pend, first if pend == "CASE-0001" else follow_choice) == "", "decide %s" % pend)
		snaps[s.world.tick] = _snap(s)
		s.advance_quarter()
		s.present_next_case()
	snaps[s.world.tick] = _snap(s)
	return {"session": s, "presented": presented, "snapshots": snaps}


func _snap(s: Session) -> Dictionary:
	var w := s.world
	return {
		"dki_damage": w.get_v("damage", w.region_index[DKI]),
		"dki_sentiment": w.get_v("sentiment", w.region_index[DKI]),
		"dki_infra": w.get_v("infrastructure", w.region_index[DKI]),
		"bogor_damage": w.get_v("damage", w.region_index[BOGOR]),
		"control_sentiment": w.get_v("sentiment", w.region_index[CONTROL]),
		"control_price": w.get_v("price_level", w.region_index[CONTROL]),
		"fiscal_space": float(w.national.fiscal_space),
		"nat_sentiment": w.national_mean("sentiment"),
		"nat_welfare": w.national_mean("welfare"),
	}


func test_real_facts_are_attributed_and_briefing_is_fiction() -> void:
	var c: Dictionary = _json("res://data/cases/CASE-0001.json")
	t.check(c.real_context.lines.size() >= 2, "at least 2 real fact lines")
	for line in c.real_context.lines:
		t.check(line.source_refs.size() >= 1 and str(line.as_of).length() == 10, "each fact has source + date")
	t.check(c.briefing.fact_class == "FICTIONAL", "briefing labeled FICTIONAL")
	t.check(c.choices.size() == 3, "three decisions")
	t.check(c.follow_ups.size() == 4, "three branches + recurring flood declared")
	t.check(c.exposure_note.fact_class == "DERIVED", "exposure reveal documented as DERIVED, not fact")


func test_immediate_vs_delayed_consequences() -> void:
	var s := _session()
	s.present_next_case()
	t.check(s.pending_case() == "CASE-0001", "reference case opens the run")
	var i: int = s.world.region_index[DKI]
	s.decide("CASE-0001", "a")
	var fiscal0 := float(s.world.national.fiscal_space)
	s.sim.step_month(s.world)  # month 1: trigger damage + immediate effects
	var dmg_m1 := s.world.get_v("damage", i)
	t.check(float(s.world.national.fiscal_space) < fiscal0, "immediate: fiscal cost applied in decision month")
	t.check(dmg_m1 > 20.0, "immediate: flood damage present (got %f)" % dmg_m1)
	s.sim.step_month(s.world)  # month 2: delayed -15 damage lands
	t.check(s.world.get_v("damage", i) < dmg_m1 - 15.0, "delayed: response reduces damage one month later")

	var s2 := _session()
	s2.present_next_case()
	s2.decide("CASE-0001", "c")
	var prot0 := s2.world.get_v("flood_protection", i)
	for _m in 6:
		s2.sim.step_month(s2.world)
	t.near(s2.world.get_v("flood_protection", i), prot0, 0.0001, "delayed: no flood protection before 6 months")
	s2.sim.step_month(s2.world)
	t.near(s2.world.get_v("flood_protection", i), prot0 + 30.0, 0.0001, "delayed: +30 flood protection at month 7")


func test_regional_vs_national_consequences() -> void:
	var r := _play("a")
	var snaps: Dictionary = r.snapshots
	var q1: Dictionary = snaps[3]
	t.check(q1.dki_sentiment < 54.0, "regional: DKI sentiment falls after the flood")
	t.check(absf(q1.control_sentiment - 55.0) < 1.0, "regional: distant region barely affected")
	t.check(q1.control_price > 100.0, "national: emergent food-price spillover reaches distant region (%f)" % q1.control_price)
	t.check(q1.fiscal_space < 50.0, "national: fiscal space reduced")


func test_sentiment_recovers_after_response() -> void:
	# Isolate recovery dynamics: no background floods in the case regions after the 2020 event.
	var s := _session()
	var f: PackedFloat64Array = s.world.vars["flood_frequency"]
	for id in ["31.71", "31.72", "31.73", "31.74", "31.75", "32.01", "36.02"]:
		f[s.world.region_index[id]] = 0.0
	s.world.vars["flood_frequency"] = f
	var i: int = s.world.region_index[DKI]
	s.present_next_case()
	s.decide("CASE-0001", "a")
	var sent := {}
	var dmg := {}
	for m in 13:
		sent[s.world.tick] = s.world.get_v("sentiment", i)
		dmg[s.world.tick] = s.world.get_v("damage", i)
		s.sim.step_month(s.world)
	# Welfare/price smoothing and trust erosion make sentiment lag damage: trough, then recovery.
	t.check(dmg[9] < dmg[3] * 0.7, "damage repaired over the dry season")
	t.check(sent[12] > sent[9], "sentiment recovers after its lagged trough")
	t.check(sent[9] < sent[0], "still below pre-flood level at the trough")


func test_real_recurring_floods_can_stall_recovery() -> void:
	# With BNPB-derived frequencies, rainy-season floods can re-damage a recovering region.
	var s := _session()
	var i: int = s.world.region_index[DKI]
	s.present_next_case()
	s.decide("CASE-0001", "a")
	var refloods := 0
	for m in 24:
		s.sim.step_month(s.world)
		if s.world.tick > 3 and s.world.get_v("flood_events_last", i) > 0.0:
			refloods += 1
	t.check(refloods > 0, "Jakarta Pusat (BNPB rate ~5/yr) floods again within two years")


func test_branching_each_choice_opens_its_own_follow_up() -> void:
	var a := _play("a")
	var b := _play("b")
	var c := _play("c")
	t.check("CASE-0001-A" in a.presented and not ("CASE-0001-B" in a.presented or "CASE-0001-C" in a.presented), "a -> A only: %s" % str(a.presented))
	t.check("CASE-0001-C" in c.presented and not ("CASE-0001-A" in c.presented or "CASE-0001-B" in c.presented), "c -> C only: %s" % str(c.presented))
	t.check(not ("CASE-0001-A" in b.presented or "CASE-0001-C" in b.presented), "b never opens A or C: %s" % str(b.presented))
	# Outcomes diverge materially by the end of the term.
	var ea: Dictionary = a.snapshots[60]
	var ec: Dictionary = c.snapshots[60]
	t.check(ec.dki_infra > ea.dki_infra, "infrastructure path ends with more DKI infrastructure")
	t.check(absf(ea.fiscal_space - ec.fiscal_space) > 1.0, "fiscal outcomes differ")


func test_follow_up_b_is_state_dependent() -> void:
	# Lagging recovery opens CASE-0001-B ...
	var s := _session()
	s.present_next_case()
	s.decide("CASE-0001", "b")
	EffectQueue.schedule(s.world, [{"scope": "regions:32.01,36.02", "var": "damage", "op": "add", "value": 30.0, "delay": 1}], "test:extra_shock")
	s.advance_quarter()
	t.check(s.present_next_case() == "CASE-0001-B", "B opens when Bogor/Lebak damage stays high")
	# ... but a fast recovery (forced) keeps it closed.
	var s2 := _session()
	s2.present_next_case()
	s2.decide("CASE-0001", "b")
	EffectQueue.schedule(s2.world, [{"scope": "regions:32.01,36.02", "var": "damage", "op": "set", "value": 0.0, "delay": 1, "duration": 3}], "test:fast_recovery")
	s2.advance_quarter()
	t.check(s2.present_next_case() != "CASE-0001-B", "B stays closed when recovery is fast")


func test_quarter_cannot_advance_with_pending_decision() -> void:
	var s := _session()
	s.present_next_case()
	t.check(s.advance_quarter().is_empty(), "no ticks while CASE-0001 undecided")
	t.check(s.world.tick == 0, "tick unchanged")


func test_golden_master() -> void:
	var result := {}
	for ch in ["a", "b", "c"]:
		var r := _play(ch)
		var end: Dictionary = r.snapshots[60]
		var rounded := {}
		for k in end:
			rounded[k] = snappedf(end[k], 0.0001)
		result[ch] = {"presented": r.presented, "end": rounded}
	if OS.get_environment("NUSANTARA_UPDATE_GOLDEN") == "1":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/golden"))
		var f := FileAccess.open(GOLDEN, FileAccess.WRITE)
		f.store_string(JSON.stringify(result, "  ", true))
		f.close()
		print("    golden master updated: ", GOLDEN)
		return
	t.check(FileAccess.file_exists(GOLDEN), "golden file exists (run with NUSANTARA_UPDATE_GOLDEN=1 once)")
	if not FileAccess.file_exists(GOLDEN):
		return
	var expected: Dictionary = _json(GOLDEN)
	for ch in result:
		t.check(result[ch].presented == expected[ch].presented, "choice %s: case sequence changed %s vs %s" % [ch, result[ch].presented, expected[ch].presented])
		for k in result[ch].end:
			t.near(result[ch].end[k], float(expected[ch].end[k]), 0.0002, "choice %s: %s drifted from golden" % [ch, k])


## G-11 regression: mitigation must reduce flood damage for the SAME hazard events.
func test_protection_reduces_damage_of_identical_floods() -> void:
	var unprotected := _flood_run("a", "a")
	var protected := _flood_run("c", "b")
	t.check(unprotected.events == protected.events, "same hazard events in both runs (paired, counter RNG): %s vs %s" % [unprotected.events, protected.events])
	t.check(unprotected.events.size() > 0, "recurring floods occur in exposed regions")
	# Floods before protection is built (month 7) count too, so the term-level cut is below the
	# per-event 45% (exact per-event math is tested in test_flood_calibration).
	t.check(protected.damage < unprotected.damage * 0.9, "protection cuts cumulative flood damage by >10%% (%f vs %f)" % [protected.damage, unprotected.damage])
	t.check(protected.r_count <= unprotected.r_count, "fewer or equal recurring crises when protected")


func test_control_region_floods_only_by_its_own_rate() -> void:
	# Denpasar has no IRBI score and no 2024 record: it keeps a small labeled province-proxy rate,
	# so floods are possible but rare (no artificial suppression, no invented high hazard).
	var r := _flood_run("a", "a")
	t.check(r.control_floods <= 6, "proxy-rate region floods rarely over a term (got %d)" % r.control_floods)


func test_recurring_case_respects_cooldown_and_cap() -> void:
	var s := _session()
	var triggers: Array = []
	s.present_next_case()
	while not s.world.is_term_over():
		var pend := s.pending_case()
		if pend != "":
			if pend == "CASE-0001-R":
				triggers.append(s.world.tick)
			s.decide(pend, "a")
		s.advance_quarter()
		s.present_next_case()
	t.check(triggers.size() >= 1 and triggers.size() <= 3, "R occurs 1..3 times (got %d)" % triggers.size())
	for k in range(1, triggers.size()):
		t.check(triggers[k] - triggers[k - 1] >= 9, "cooldown >= 9 months between recurrences")


func test_where_scope_targets_flooded_regions_at_decision_time() -> void:
	var s := _session()
	var w := s.world
	var f: PackedFloat64Array = w.vars["flood_frequency"]
	f.fill(0.0)  # isolate the scope mechanism from background floods
	w.vars["flood_frequency"] = f
	var i: int = w.region_index[DKI]
	var j: int = w.region_index[CONTROL]
	w.set_v("flood_damage_last", i, 10.0)
	w.set_v("damage", i, 30.0)
	w.set_v("damage", j, 30.0)
	EffectQueue.schedule(w, [{"scope": "where:flood_damage_last>0", "var": "damage", "op": "add", "value": -8.0, "delay": 1}], "test")
	t.check(str(w.pending_effects[-1].scope) == "regions:" + DKI, "resolved to explicit region list at scheduling")
	w.set_v("flood_damage_last", i, 0.0)  # later state changes must not retarget
	s.sim.step_month(w)
	s.sim.step_month(w)
	t.check(w.get_v("damage", i) < w.get_v("damage", j) - 7.0, "only the flooded region received relief")


func test_save_load_mid_term_preserves_floods_budget_and_recurrence() -> void:
	var a := _session()
	a.set_budget(1.1, {"infrastruktur": 25.0, "kebencanaan": 25.0, "layanan": 30.0, "pangan": 20.0})
	a.present_next_case()
	for _q in 6:
		var pend := a.pending_case()
		if pend != "":
			a.decide(pend, "c")
		a.advance_quarter()
		a.present_next_case()
	var dir := "user://test_saves_case0001"
	var svc := SaveService.new(dir)
	t.check(svc.save("mid", "mid", a.world.to_dict()) == "", "save mid-term")
	var b := _session()
	var r := svc.load_slot("mid")
	t.check(b.world.load_dict(r.payload) == "", "load")
	for s in [a, b]:
		while not s.world.is_term_over():
			var pend: String = s.pending_case()
			if pend != "":
				s.decide(pend, "b")
			s.advance_quarter()
			s.present_next_case()
	t.check(a.world.vars["damage"] == b.world.vars["damage"], "identical damage history after reload")
	t.check(a.world.vars["flood_protection"] == b.world.vars["flood_protection"], "identical protection after reload")
	t.check(a.world.case_state == b.world.case_state, "identical case history after reload")
	t.near(float(a.world.national.fiscal_space), float(b.world.national.fiscal_space), 0.0, "identical fiscal space")
	t.check(float(b.world.national.budget_level) == 1.1 or float(b.world.national.fiscal_space) <= 0.0, "budget level persisted")


func _flood_run(first: String, recurring: String) -> Dictionary:
	var s := _session()
	var focus: Array = ["31.71", "31.72", "31.73", "31.74", "31.75", "32.01", "36.02"].map(func(id): return s.world.region_index[id])
	var j: int = s.world.region_index[CONTROL]
	var out := {"events": [], "damage": 0.0, "control_floods": 0, "r_count": 0}
	s.present_next_case()
	while not s.world.is_term_over():
		var pend := s.pending_case()
		if pend != "":
			if pend == "CASE-0001-R":
				out.r_count += 1
			s.decide(pend, first if pend == "CASE-0001" else (recurring if pend == "CASE-0001-R" else "a"))
		for _m in 3:
			if s.world.is_term_over():
				break
			s.sim.step_month(s.world)
			for i in focus:
				var f := s.world.get_v("flood_damage_last", i)
				if f > 0.0:
					out.events.append("%d:%d" % [s.world.tick, i])
					out.damage += f
			if s.world.get_v("flood_damage_last", j) > 0.0:
				out.control_floods += 1
		s.present_next_case()
	return out


## Regression (2026-10-06): CASE-0001-R relief used "where:flood_damage_last>0" over ALL regions, so a
## Jakarta case funded relief nationwide once real frequencies flooded ~190 regions per peak month.
func test_recurring_relief_stays_in_case_area() -> void:
	var s := _session()
	var w := s.world
	var far: int = w.region_index[BOGOR]
	var outside: int = w.region_index["73.17"]  # Kab. Luwu, flooded but not in the case area
	for i in [far, outside]:
		w.set_v("flood_damage_last", i, 5.0)
	var r_case: Dictionary = _all_cases()["CASE-0001-R"]
	EffectQueue.schedule(w, r_case.choices[0].effects, "test:R/a")
	var scopes: Array = w.pending_effects.map(func(e): return str(e.scope))
	var damage_scope: String = scopes.filter(func(sc): return sc.begins_with("regions:"))[0]
	t.check(damage_scope.contains(BOGOR), "flooded case region receives relief")
	t.check(not damage_scope.contains("73.17"), "flooded region outside the case area does not")
