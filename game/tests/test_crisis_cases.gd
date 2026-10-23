extends RefCounted
## Crisis cases through the regional loop (D-066..D-068): CASE-0002 (Palu 2018), CASE-0003 (cooking oil
## 2022) and CASE-0004 (peat fires 2015) — regional attribution, national drivers, documented scoping,
## inspectable follow-up triggers, multi-quarter horizons.

var t
const PALU := "72.71"
const SIGI := "72.10"
const DONGGALA := "72.03"
const KAPUAS := "62.03"
const PALANGKA := "62.71"
const DENPASAR := "51.71"


func _j(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _session(family: String) -> Session:
	var cases := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		if f.ends_with(".json") and f.begins_with(family):
			var c: Dictionary = _j("res://data/cases/" + f)
			cases[c.case_id] = c
	var pols := {}
	for f in DirAccess.get_files_at("res://data/policies"):
		if f.ends_with(".json"):
			var p: Dictionary = _j("res://data/policies/" + f)
			pols[p.policy_id] = p
	return Session.new(_j("res://data/sim_params.json"), _j("res://data/regions.json").regions,
		_j("res://data/baseline.json"), cases, 11, _j("res://data/budget.json"), pols)


## Fast-forwards to the case and decides it.
func _decided(family: String, choice: String) -> Session:
	var s := _session(family)
	while s.present_next_case() != family and not s.world.is_term_over():
		s.advance_quarter()
	t.check(s.decide(family, choice) == "", "%s decided %s" % [family, choice])
	return s


func _cause(s: Session, v: String, key: String, region: String) -> float:
	var arr: PackedFloat64Array = s.world.ledger.causes.get(v, {}).get(key, PackedFloat64Array())
	return arr[s.world.region_index[region]] if not arr.is_empty() else 0.0


func _exact(s: Session, v: String) -> float:
	var worst := 0.0
	var w := s.world
	for i in w.region_count():
		var sum := 0.0
		for c in w.ledger.causes.get(v, {}):
			sum += (w.ledger.causes[v][c] as PackedFloat64Array)[i]
		worst = maxf(worst, absf(sum - (w.vars[v][i] - w.ledger.start[v][i])))
	return worst


func test_case0002_choices_diverge_regionally_over_several_quarters() -> void:
	var dmg := {}
	var horizon := {}
	for ch in ["a", "b", "c"]:
		var s := _decided("CASE-0002", ch)
		s.advance_quarter()
		var i: int = s.world.region_index[PALU]
		t.check(_cause(s, "damage", "eff:case:CASE-0002/trigger#now", PALU) == 45.0, "%s: quake damage attributed to the case event in Palu" % ch)
		t.check(_cause(s, "damage", "eff:case:CASE-0002/trigger#now", DENPASAR) == 0.0, "no quake damage far away")
		var last := 0
		for e in s.world.pending_effects:
			if str(e.source).begins_with("case:CASE-0002/choice"):
				last = maxi(last, int(e.apply_tick) - s.world.tick)
		horizon[ch] = last
		s.advance_quarter()
		dmg[ch] = s.world.vars.damage[i]
		t.check(_exact(s, "damage") < 1e-9, "%s: damage causes exact" % ch)
	t.check(dmg.a < dmg.c and dmg.c < dmg.b, "rebuild-in-place clears damage fastest, relocation slowest (a %.1f, c %.1f, b %.1f)" % [dmg.a, dmg.c, dmg.b])
	t.check(int(horizon.b) >= 6, "relocation keeps consequences scheduled for later quarters (%d months)" % int(horizon.b))
	t.check(int(horizon.a) == 0, "rebuild-in-place has no long tail")


func test_case0002_follow_up_trigger_is_inspectable() -> void:
	var s := _decided("CASE-0002", "b")
	var id := ""
	while id == "" and not s.world.is_term_over():
		s.advance_quarter()
		id = s.present_next_case()
	t.check(id == "CASE-0002-B", "relocation leads to the red-zone follow-up (got %s)" % id)
	var c: Dictionary = s.cases.cases[id]
	var trust := 0.0
	for r in [PALU, SIGI]:
		trust += s.world.vars.trust[s.world.region_index[r]] / 2.0
	t.check(trust < 54.0, "documented condition holds: Palu/Sigi trust %.1f < 54" % trust)
	t.check(Conditions.eval(s.world, c.trigger.conditions), "trigger conditions true at presentation")
	var lines := ChangeText.describe_conditions(s.world, c.trigger.conditions)
	t.check(lines.size() == 3 and lines.all(func(l): return str(l).begins_with("✓")), "every condition described as met: %s" % str(lines))
	t.check(str(lines[2]).contains("= " + Fmt.num(trust, 1)) and str(lines[2]).contains("(syarat < 54"), "shows the actual trust value: %s" % lines[2])


func test_case0003_regional_prices_attributed_to_shock_and_decision() -> void:
	var s := _decided("CASE-0003", "a")
	s.advance_quarter()
	var shock := _cause(s, "price_level", "drv:price_pressure|case:CASE-0003/trigger", DENPASAR)
	var ban := _cause(s, "price_level", "drv:price_pressure|case:CASE-0003/choice:a", DENPASAR)
	t.check(shock > 0.5, "the commodity shock raises prices even far from Sumatra (%.2f)" % shock)
	t.check(ban < 0.0, "the export ban's relief is attributed to the ban (%.2f)" % ban)
	t.check(_exact(s, "price_level") < 1e-9, "price causes still sum exactly to the change")
	var nat: Dictionary = s.world.ledger.national_causes
	t.check(nat.fiscal_space.has("eff:case:CASE-0003/choice:a#now"), "fiscal cost of the ban explained nationally")
	t.check(nat.price_pressure.has("sys:pp_decay"), "shock fading recorded")
	var q: Dictionary = s.world.event_log[-1]
	t.check((q.national as Array).any(func(r): return r.key == "price_pressure"), "quarter summary explains national price pressure")


func test_case0003_costs_and_benefits_fall_on_different_regions() -> void:
	var ban := _decided("CASE-0003", "a")
	var cash := _decided("CASE-0003", "c")
	for s in [ban, cash]:
		s.advance_quarter()
	var riau: int = ban.world.region_index["14.01"]
	var far: int = ban.world.region_index[DENPASAR]
	t.check(ban.world.vars.welfare[riau] < cash.world.vars.welfare[riau], "export ban costs Riau producers more than cash aid")
	t.check(ban.world.vars.price_level[far] < cash.world.vars.price_level[far], "but lowers consumer prices far away more")
	t.check(ban.world.national.fiscal_space > cash.world.national.fiscal_space, "cash aid costs more fiscal space")


func test_case0004_local_wisdom_only_where_documented() -> void:
	var s := _decided("CASE-0004", "c")
	for _q in 3:
		s.advance_quarter()
	var fp: PackedFloat64Array = s.world.vars.fire_prevention
	t.check(fp[s.world.region_index[KAPUAS]] > 0.0, "community fire governance builds up in Kapuas")
	for i in s.world.region_count():
		if s.world.region_ids[i] != KAPUAS and fp[i] != 0.0:
			t.check(false, "no adat fire prevention outside Kapuas (%s = %.2f)" % [s.world.region_ids[i], fp[i]])
			break
	var r := _decided("CASE-0004", "b")
	for _q in 3:
		r.advance_quarter()
	t.check(r.world.vars.fire_prevention[r.world.region_index[PALANGKA]] > 0.0, "restoration acts province-wide (BRG priority province)")


func test_drivers_saved_and_old_saves_marked_unrecorded() -> void:
	var s := _decided("CASE-0003", "b")
	s.advance_quarter()
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.world.to_dict()))
	var r := _session("CASE-0003")
	t.check(r.world.load_dict(d) == "", "v5 loads")
	t.check(SaveCodec.encode(r.world.drivers) == SaveCodec.encode(s.world.drivers), "drivers restored exactly")
	s.advance_quarter()
	r.advance_quarter()
	t.check(s.world.vars.price_level == r.world.vars.price_level, "same future after reload")
	d.schema = 4
	d.erase("drivers")
	var old := _session("CASE-0003")
	t.check(old.world.load_dict(d) == "", "v4 save migrates")
	var fr := SimLedger.driver_fractions(old.world, "price_pressure", float(old.world.national.price_pressure))
	t.check(fr.keys() == [SimLedger.UNRECORDED], "pre-v5 pressure is reported as unrecorded, not guessed")
