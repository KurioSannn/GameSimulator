extends RefCounted
## CASE-0003 (2022 cooking-oil crisis / CPO export ban) regression + golden master.
## Chain tests use hazard-free worlds so floods do not mask the price mechanism.

var t
const GOLDEN := "res://tests/golden/case0003.json"
const FAR := "51.71"     # Kota Denpasar: far from palm-oil provinces (national price channel only)
const RIAU_CITY := "14.71"


func _j(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _cases() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		if f.ends_with(".json") and f.begins_with("CASE-0003"):
			var c: Dictionary = _j("res://data/cases/" + f)
			out[c.case_id] = c
	return out


func _session(cases: Dictionary, hazard_free := true, seed_value := 11) -> Session:
	var s := Session.new(_j("res://data/sim_params.json"), _j("res://data/regions.json").regions, _j("res://data/baseline.json"),
		cases, seed_value, _j("res://data/budget.json"))
	if hazard_free:
		var f: PackedFloat64Array = s.world.vars["flood_frequency"]
		f.fill(0.0)
		s.world.vars["flood_frequency"] = f
	return s


func _to_case(s: Session) -> void:
	while s.present_next_case() != "CASE-0003" and not s.world.is_term_over():
		s.advance_quarter()


func _prov_mean(s: Session, v: String, prov: String) -> float:
	var idx := EffectQueue.resolve_scope(s.world, "province:" + prov)
	var acc := 0.0
	for i in idx:
		acc += s.world.get_v(v, i)
	return acc / idx.size()


func test_presented_in_april_of_year_four() -> void:
	var s := _session(_cases())
	_to_case(s)
	t.check(s.world.tick == 39 and s.sim.month_of(s.world.tick) == 4, "presented at month 39 (April) — got %d" % s.world.tick)


func test_cross_system_chain_price_to_welfare_to_sentiment() -> void:
	var shocked := _session(_cases())
	var control := _session({})
	_to_case(shocked)
	while control.world.tick < shocked.world.tick:
		control.advance_quarter()
	shocked.decide("CASE-0003", "b")  # slowest relief: the shock stays visible for a while
	for z in [shocked, control]:
		for _m in 4:
			z.sim.step_month(z.world)
	var i: int = shocked.world.region_index[FAR]
	t.check(shocked.world.get_v("price_level", i) > control.world.get_v("price_level", i) + 1.0, "national price pressure raises prices far from Sumatra")
	t.check(shocked.world.get_v("welfare", i) < control.world.get_v("welfare", i), "-> lower welfare")
	t.check(shocked.world.get_v("sentiment", i) < control.world.get_v("sentiment", i), "-> lower sentiment")
	t.check(float(shocked.world.national.price_pressure) > 0.0, "pressure still present")


func test_export_ban_relieves_prices_fast_but_hurts_producers() -> void:
	var a := _session(_cases())
	var b := _session(_cases())
	var c := _session(_cases())
	var riau0 := _prov_mean(a, "welfare", "14")  # calibrated starts differ by province (BPS IPM)
	var sumsel0 := _prov_mean(a, "welfare", "16")
	for pair in [[a, "a"], [b, "b"], [c, "c"]]:
		_to_case(pair[0])
		pair[0].decide("CASE-0003", pair[1])
		for _m in 3:
			pair[0].sim.step_month(pair[0].world)
	t.check(float(a.world.national.price_pressure) < float(b.world.national.price_pressure), "ban relieves price pressure faster than DMO")
	t.check(_prov_mean(a, "welfare", "14") < _prov_mean(c, "welfare", "14"), "ban lowers Riau welfare vs subsidy path")
	t.check(_prov_mean(a, "welfare", "14") - riau0 < _prov_mean(a, "welfare", "16") - sumsel0, "Riau hit harder than Sumatera Selatan (documented TBS decline ~2x)")
	t.check(_prov_mean(a, "trust", "14") < _prov_mean(b, "trust", "14"), "producer trust falls under the ban")
	t.check(float(c.world.national.fiscal_space) < float(a.world.national.fiscal_space), "subsidy + cash is the most expensive option")


func test_cash_support_is_largest_where_welfare_is_lowest() -> void:
	var s := _session(_cases())
	var lo: int = s.world.region_index["91.71"]
	var hi: int = s.world.region_index["31.71"]
	s.world.set_v("welfare", lo, 40.0)
	s.world.set_v("welfare", hi, 70.0)
	_to_case(s)
	var lo0 := s.world.get_v("welfare", lo)
	var hi0 := s.world.get_v("welfare", hi)
	s.decide("CASE-0003", "c")
	s.sim.step_month(s.world)
	t.check(s.world.get_v("welfare", lo) - lo0 > s.world.get_v("welfare", hi) - hi0, "regional response: targeted cash helps low-welfare regions more")


func _play(choice: String, follow := "a", hazard_free := true) -> Array:
	var s := _session(_cases(), hazard_free)
	s.present_next_case()
	var seen := []
	while not s.world.is_term_over():
		var p := s.pending_case()
		if p != "":
			seen.append(p)
			s.decide(p, choice if p == "CASE-0003" else follow)
		s.advance_quarter()
		s.present_next_case()
	return [s, seen]


func test_each_choice_opens_its_own_follow_up() -> void:
	var a: Array = _play("a")[1]
	var b: Array = _play("b")[1]
	var c: Array = _play("c")[1]
	t.check("CASE-0003-A" in a and not ("CASE-0003-B" in a or "CASE-0003-C" in a), "ban -> farmer follow-up only: %s" % str(a))
	t.check("CASE-0003-B" in b and not ("CASE-0003-A" in b or "CASE-0003-C" in b), "DMO -> compliance follow-up only: %s" % str(b))
	t.check("CASE-0003-C" in c and not ("CASE-0003-A" in c or "CASE-0003-B" in c), "subsidy -> cash-ends follow-up only: %s" % str(c))


func test_follow_up_a_is_state_dependent() -> void:
	var s := _session(_cases())
	_to_case(s)
	s.decide("CASE-0003", "a")
	# "Held high" relative to Riau's calibrated start (mean IPM 2024 ~73.5), well above the trigger (start - 1).
	EffectQueue.schedule(s.world, [{"scope": "province:14", "var": "welfare", "op": "set", "value": 80.0, "delay": 1, "duration": 12}], "test:riau_welfare_held_high")
	var seen := []
	while not s.world.is_term_over():
		var p := s.pending_case()
		if p != "":
			seen.append(p)
			s.decide(p, "a")
		s.advance_quarter()
		s.present_next_case()
	t.check(not ("CASE-0003-A" in seen), "farmer follow-up stays closed when Riau welfare holds: %s" % str(seen))


func test_golden_master() -> void:
	var result := {}
	for ch in ["a", "b", "c"]:
		var r := _play(ch, "a", false)
		var s: Session = r[0]
		var end := {
			"national_price": snappedf(s.world.national_mean("price_level"), 0.0001),
			"national_welfare": snappedf(s.world.national_mean("welfare"), 0.0001),
			"national_sentiment": snappedf(s.world.national_mean("sentiment"), 0.0001),
			"riau_welfare": snappedf(_prov_mean(s, "welfare", "14"), 0.0001),
			"riau_trust": snappedf(_prov_mean(s, "trust", "14"), 0.0001),
			"price_pressure": snappedf(float(s.world.national.price_pressure), 0.000001),
			"fiscal_space": snappedf(float(s.world.national.fiscal_space), 0.0001),
		}
		result[ch] = {"presented": r[1], "end": end}
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
