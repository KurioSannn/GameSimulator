extends RefCounted
## Regional simulation integration (D-062..D-064): decision -> regional consequences -> exact
## per-region attribution (SimLedger) -> event log -> national aggregation -> save/load.

var t
const DKI := "31.71"
const BOGOR := "32.01"
const DENPASAR := "51.71"  # far from CASE-0001


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _session(seed_value := 11) -> Session:
	var cases := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		if f.ends_with(".json") and f.begins_with("CASE-0001"):
			var c: Dictionary = _json("res://data/cases/" + f)
			cases[c.case_id] = c
	return Session.new(_json("res://data/sim_params.json"), _json("res://data/regions.json").regions,
		_json("res://data/baseline.json"), cases, seed_value, _json("res://data/budget.json"))


func _decided(choice: String) -> Session:
	var s := _session()
	t.check(s.present_next_case() == "CASE-0001", "CASE-0001 presented first")
	t.check(s.decide("CASE-0001", choice) == "", "decide %s" % choice)
	return s


func _cause_sum(w: SimWorld, v: String, i: int) -> float:
	var sum := 0.0
	for c in w.ledger.causes.get(v, {}):
		sum += (w.ledger.causes[v][c] as PackedFloat64Array)[i]
	return sum


func test_no_time_advance_while_decision_pending() -> void:
	var s := _session()
	s.present_next_case()
	t.check(s.advance_quarter().is_empty(), "no reports while CASE-0001 is undecided")
	t.check(s.world.tick == 0, "tick unchanged")
	t.check(not SimLedger.active(s.world), "no quarter ledger opened")


func test_ledger_causes_sum_exactly_to_change_for_all_514_regions() -> void:
	var s := _decided("a")
	for _q in 3:
		s.advance_quarter()
	var w := s.world
	t.check(w.region_count() == 514, "514 regions simulated")
	var worst := 0.0
	for v in w.ledger.start:
		t.check((w.ledger.start[v] as PackedFloat64Array).size() == 514, "%s start covers all regions" % v)
		for i in 514:
			var d: float = w.vars[v][i] - w.ledger.start[v][i]
			worst = maxf(worst, absf(_cause_sum(w, v, i) - d))
	t.check(worst < 1e-9, "sum of causes == change for every variable and region (max error " + str(worst) + ")")
	t.check(int(w.ledger.start_tick) == w.tick - 3, "ledger spans the last quarter")


func test_ledger_is_observational_outcomes_unchanged() -> void:
	# Same decision; one world advanced via Session (ledger on), one via raw step_month (ledger off).
	var a := _decided("a")
	var b := _decided("a")
	for _q in 4:
		a.advance_quarter()
		for _m in 3:
			b.sim.step_month(b.world)
	t.check(not SimLedger.active(b.world), "raw stepping records nothing")
	for v in a.world.vars:
		t.check(a.world.vars[v] == b.world.vars[v], "%s bit-identical with and without ledger" % v)
	t.check(a.world.national == b.world.national, "national state identical")


func test_decision_is_attributed_and_choices_differ() -> void:
	var a := _decided("a")
	var b := _decided("b")
	a.advance_quarter()
	b.advance_quarter()
	var i: int = a.world.region_index[DKI]
	var trust_a: Dictionary = a.world.ledger.causes.trust
	t.check(trust_a.has("eff:case:CASE-0001/choice:a#now"), "choice a trust effect attributed as immediate")
	t.check((trust_a["eff:case:CASE-0001/choice:a#now"] as PackedFloat64Array)[i] > 0.0, "it raised DKI trust")
	var dmg_a: Dictionary = a.world.ledger.causes.damage
	t.check(dmg_a.has("eff:case:CASE-0001/choice:a#delayed"), "delayed damage relief attributed as delayed")
	t.check(a.world.ledger.causes.services.has("eff:case:CASE-0001/choice:a#ongoing"), "multi-month services effect attributed as ongoing")
	for k in b.world.ledger.causes.get("trust", {}):
		t.check(not str(k).contains("choice:a"), "choice b world has no choice-a causes")
	t.check(a.world.vars.trust[i] != b.world.vars.trust[i], "different choices -> different DKI trust")
	var far: int = a.world.region_index[DENPASAR]
	for c in a.world.ledger.causes.trust:
		if str(c).begins_with("eff:"):
			t.check((a.world.ledger.causes.trust[c] as PackedFloat64Array)[far] == 0.0, "decision effect does not reach Denpasar directly")
	var rows := SimLedger.region_changes(a.world, i)
	t.check(not rows.is_empty(), "panel rows for DKI")


func test_event_log_records_decision_and_quarter() -> void:
	var s := _decided("a")
	var log: Array = s.world.event_log
	t.check(log.size() == 2 and log[0].kind == "case" and log[1].kind == "decision", "case trigger and decision logged")
	t.check(not (log[0].effects as Array).is_empty(), "trigger entry lists the case's own effects")
	var e: Dictionary = log[1]
	t.check(e.choice_id == "a" and e.title != "", "entry names case and choice")
	var by_var := {}
	for fx in e.effects:
		by_var[str(fx.var) + "@" + str(fx.scope)] = fx
	t.check(by_var.has("damage@province:31") and int(by_var["damage@province:31"].regions) == 6, "DKI province effect: 6 regions")
	t.check(int(by_var["damage@province:31"].delay_months) == 1, "delay recorded as authored")
	t.check(int(by_var["fiscal_space@national"].regions) == -1, "national effect marked national")
	s.advance_quarter()
	var q: Dictionary = s.world.event_log[-1]
	t.check(q.kind == "quarter" and int(q.tick) == 3 and int(q.from_tick) == 0, "quarter summary logged")
	t.check(q.weighting == "population", "summary states the weighting used (BPS population, all 514 regions)")
	for _k in 60:
		SimLedger.log_event(s.world, {"kind": "test", "tick": 0})
	t.check(s.world.event_log.size() == SimLedger.LOG_CAP, "log is capped")


func test_national_weighting_is_explicit_never_mixed() -> void:
	var s := _session()
	var w := s.world
	t.check(w.national_weighting() == "population", "calibrated population (BPS) for all 514 -> population weights")
	var sum := 0.0
	for x in w.vars.welfare:
		sum += x
	var pop: PackedFloat64Array = w.vars.population
	var real_pop := pop.duplicate()
	pop[0] = 0.0  # one region without data
	w.vars.population = pop
	t.check(w.national_weighting() == "equal", "partial population data does not switch to mixed weighting")
	t.near(w.national_mean("welfare"), sum / 514.0, 1e-9, "equal weights over all 514 when any weight is missing")
	w.vars.population = real_pop
	pop.fill(1000.0)
	pop[0] = 3000.0
	w.vars.population = pop
	var wel: PackedFloat64Array = w.vars.welfare
	var expect := (sum - wel[0] + 3.0 * wel[0]) / 516.0
	t.check(w.national_weighting() == "population", "complete population data -> population weights")
	t.near(w.national_mean("welfare"), expect, 1e-9, "population-weighted mean")


func test_save_load_restores_ledger_log_and_future_exactly() -> void:
	var s := _decided("c")
	s.advance_quarter()
	var saved := JSON.stringify(s.world.to_dict())
	s.advance_quarter()
	var r := _session()
	t.check(r.world.load_dict(JSON.parse_string(saved)) == "", "load ok")
	t.check(r.world.tick == 3, "time restored")
	t.check(r.world.event_log.size() == 3, "event log restored")
	t.check(SimLedger.active(r.world) and int(r.world.ledger.start_tick) == 0, "ledger restored")
	t.check(not r.world.pending_effects.is_empty(), "pending delayed consequences restored")
	var before := SimLedger.region_changes(r.world, r.world.region_index[DKI])
	t.check(not before.is_empty(), "restored ledger explains DKI")
	r.advance_quarter()
	for v in s.world.vars:
		t.check(s.world.vars[v] == r.world.vars[v], "%s bit-identical after reload + quarter" % v)
	t.check(SaveCodec.encode(s.world.ledger) == SaveCodec.encode(r.world.ledger), "ledger identical after reload + quarter")
	t.check(JSON.stringify(SaveCodec.encode(s.world.event_log)) == JSON.stringify(SaveCodec.encode(r.world.event_log)), "event log identical")


func test_v3_save_migrates_to_v4() -> void:
	var s := _decided("a")
	s.advance_quarter()
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.world.to_dict()))
	d.schema = 3
	d.erase("ledger")
	d.erase("event_log")
	var r := _session()
	t.check(r.world.load_dict(d) == "", "v3 save loads")
	t.check(not SimLedger.active(r.world) and r.world.event_log.is_empty(), "no attribution for pre-v4 history")
	t.check(r.world.vars.trust == s.world.vars.trust and r.world.tick == 3, "state restored")
	t.check(r.world.to_dict().schema == SimWorld.SAVE_SCHEMA, "re-saved as current schema")
	r.advance_quarter()
	t.check(SimLedger.active(r.world), "ledger starts with the next quarter")


func test_change_text_explains_actual_causes() -> void:
	t.check(ChangeText.cause_label("sys:floods").contains("Banjir"), "system cause label")
	var label := ChangeText.cause_label("eff:case:CASE-0001/choice:a#now")
	t.check(label.contains("efek segera") and label.contains("«"), "decision cause names the case and timing: %s" % label)
	t.check(ChangeText.cause_label("eff:case:CASE-0001/choice:a#delayed").contains("tertunda"), "delayed label")
	var s := _decided("a")
	var txt := ChangeText.entry_text(s.world.event_log[1])
	t.check(txt.contains("Provinsi") and txt.contains("tertunda 1 bulan"), "decision log text matches scheduled effects")
