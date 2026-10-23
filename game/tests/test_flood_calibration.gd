extends RefCounted
## G-13/G-14 regression: official vs derived separation, coverage classes, no suppression,
## mitigation and resilience effects on identical flood events.

var t
const IRBI_AND_HISTORY := "32.01"   # Kab. Bogor: IRBI listed + BNPB 2024 events
const HISTORY_NO_IRBI := "51.06"    # Kab. Bangli: no IRBI flood score, BNPB recorded floods in 2024
const NEITHER := "51.71"            # Kota Denpasar: no IRBI flood score, absent from BNPB 2024 table


func _j(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _baseline() -> Dictionary:
	return _j("res://data/baseline.json")


func _status(b: Dictionary, v: String, rid: String) -> String:
	return str(b.variables[v].region_status[b.region_order.find(rid)])


func _value(b: Dictionary, v: String, rid: String) -> float:
	return float(b.variables[v]["values"][b.region_order.find(rid)])


func test_official_index_and_derived_profile_are_distinct() -> void:
	var b := _baseline()
	var prof: Dictionary = b.variables.flood_risk_profile
	t.check(prof.status == "DERIVED", "profile is DERIVED, not REAL_OFFICIAL")
	t.check(prof.provenance.inputs == ["official_irbi_flood_score"], "profile derives from the official IRBI score")
	var params: Dictionary = _j("res://data/sim_params.json")
	t.check(str(params.variables.flood_risk_profile.unit).contains("turunan"), "derived unit labeled 'turunan'")
	var facts: Array = _j("res://data/regions.json").regions.filter(func(r): return r.region_id == IRBI_AND_HISTORY)[0].facts
	var official: Array = facts.filter(func(f): return f.id == "official_irbi_flood_score")
	t.check(official.size() == 1 and official[0].unit == "skor IRBI" and official[0].fact_class == "REAL_OFFICIAL", "official IRBI score shown as REAL fact in its own unit")


func test_region_with_irbi_and_history() -> void:
	var b := _baseline()
	t.check(_status(b, "flood_risk_profile", IRBI_AND_HISTORY) == "REAL", "IRBI-derived profile")
	t.check(_status(b, "flood_frequency", IRBI_AND_HISTORY) == "REAL", "history-derived frequency")
	t.check(_value(b, "flood_frequency", IRBI_AND_HISTORY) > 5.0, "Bogor recorded 18 floods in 2024 -> high rate")


func test_region_with_history_but_no_irbi_can_flood() -> void:
	var b := _baseline()
	t.check(_status(b, "flood_risk_profile", HISTORY_NO_IRBI) == "UNCALIBRATED", "no IRBI -> profile uncalibrated (neutral)")
	t.near(_value(b, "flood_risk_profile", HISTORY_NO_IRBI), 50.0, 1e-9, "neutral profile, not zero, not invented")
	t.check(_status(b, "flood_frequency", HISTORY_NO_IRBI) == "REAL", "frequency from BNPB history")
	t.check(_value(b, "flood_frequency", HISTORY_NO_IRBI) > 0.0, "floods possible")


func test_region_with_neither_is_proxy_not_suppressed() -> void:
	var b := _baseline()
	t.check(_status(b, "flood_risk_profile", NEITHER) == "UNCALIBRATED", "profile uncalibrated")
	var st := _status(b, "flood_frequency", NEITHER)
	t.check(st == "PROVINCE_PROXY" or st == "UNCALIBRATED", "frequency is a labeled proxy (got %s)" % st)
	t.check(_value(b, "flood_frequency", NEITHER) > 0.0, "no artificial suppression: rate > 0")


func test_no_region_has_zero_flood_rate() -> void:
	var b := _baseline()
	for v in b.variables.flood_frequency["values"]:
		if float(v) <= 0.0:
			t.check(false, "a region has a zero flood rate")
			return


func test_more_history_dominates_prior() -> void:
	var b := _baseline()
	var p: Dictionary = b.variables.flood_frequency.provenance.params
	t.check(float(p.beta_years) < 2.0, "prior strength under 2 years: observed record dominates (beta=%s)" % p.beta_years)


func _session() -> Session:
	return Session.new(_j("res://data/sim_params.json"), _j("res://data/regions.json").regions, _baseline(), {}, 21, _j("res://data/budget.json"))


func _run_term(modify: Callable) -> Dictionary:
	var s := _session()
	modify.call(s.world)
	var i: int = s.world.region_index[IRBI_AND_HISTORY]
	var out := {"events": 0, "damage": 0.0}
	while not s.world.is_term_over():
		s.sim.step_month(s.world)
		out.events += int(s.world.get_v("flood_events_last", i))
		out.damage += s.world.get_v("flood_damage_last", i)
	return out


func test_mitigation_reduces_future_damage_for_identical_events() -> void:
	var base := _run_term(func(w): pass)
	var prot := _run_term(func(w): w.set_v("flood_protection", w.region_index[IRBI_AND_HISTORY], 60.0))
	t.check(base.events == prot.events and base.events > 0, "identical flood events (%d vs %d)" % [base.events, prot.events])
	t.near(prot.damage, base.damage * (1.0 - 0.75 * 0.6), base.damage * 1e-9, "protection 60 cuts impact by exactly 45%")


func test_infrastructure_resilience_reduces_impact() -> void:
	var weak := _run_term(func(w): w.set_v("infrastructure", w.region_index[IRBI_AND_HISTORY], 20.0))
	var strong := _run_term(func(w): w.set_v("infrastructure", w.region_index[IRBI_AND_HISTORY], 80.0))
	t.check(weak.events == strong.events, "identical events")
	t.check(strong.damage < weak.damage * 0.8, "resilient infrastructure lowers impact (%f vs %f)" % [strong.damage, weak.damage])
