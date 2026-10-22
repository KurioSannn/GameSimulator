extends RefCounted

var t  # test runner


func _content() -> Dictionary:
	return {
		"regions": JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))["regions"],
		"baseline": JSON.parse_string(FileAccess.get_file_as_string("res://data/baseline.json")),
		"params": JSON.parse_string(FileAccess.get_file_as_string("res://data/sim_params.json")),
	}


## Hazard-free world (flood exposure 0 everywhere): isolates the core model's equilibrium and
## causal chains from real-data hazards, which are tested in test_case_0001/test_budget.
func _world(seed_value := 1) -> Array:
	var c := _content()
	var sim := Simulation.new(c.params, JSON.parse_string(FileAccess.get_file_as_string("res://data/budget.json")))
	var w := WorldFactory.build(c.regions, c.baseline, sim, seed_value)
	var e: PackedFloat64Array = w.vars["flood_frequency"]
	e.fill(0.0)
	w.vars["flood_frequency"] = e
	return [sim, w]


func test_real_baseline_drives_hazard_drift() -> void:
	# With real IRBI exposure, an untouched world is NOT stationary: floods occur where exposure > 0.
	var c := _content()
	var sim := Simulation.new(c.params, JSON.parse_string(FileAccess.get_file_as_string("res://data/budget.json")))
	var w := WorldFactory.build(c.regions, c.baseline, sim, 1)
	var with_rate := 0
	for v in w.vars["flood_frequency"]:
		with_rate += 1 if v > 0.0 else 0
	t.check(with_rate == 514, "every region has a positive flood rate (no artificial suppression), got %d" % with_rate)
	for _i in 12:
		sim.step_month(w)
	t.check(w.national_mean("damage") > 0.0, "real hazards produce damage")


func test_full_region_coverage() -> void:
	var p := _world()
	var sim: Simulation = p[0]
	var w: SimWorld = p[1]
	t.check(w.region_count() == 514, "expected 514 kab/kota, got %d" % w.region_count())
	t.check(w.province_ids.size() == 38, "expected 38 provinces, got %d" % w.province_ids.size())
	for v in sim.var_names():
		t.check(w.vars[v].size() == w.region_count(), "var %s length" % v)


func test_equilibrium_is_stable_without_shocks_or_hazards() -> void:
	var p := _world()
	var sim: Simulation = p[0]
	var w: SimWorld = p[1]
	var s0 := w.national_mean("sentiment")
	var wel0 := w.national_mean("welfare")  # calibrated start (BPS IPM 2024), not a fixed 55
	for _i in SimWorld.TERM_TICKS:
		sim.step_month(w)
	t.check(w.is_term_over(), "term should end after 60 ticks")
	# An unshocked world must be a stable equilibrium (no drift from model artefacts).
	t.near(w.national_mean("sentiment"), s0, 0.01, "sentiment must not drift without shocks")
	t.near(w.national_mean("price_level"), 100.0, 0.01, "prices must not drift without shocks")
	t.near(w.national_mean("welfare"), wel0, 0.01, "welfare must not drift without shocks")


func test_every_region_updates_every_tick() -> void:
	# A shock everywhere must move every region's state in one tick (no skipped regions).
	var p := _world()
	var sim: Simulation = p[0]
	var w: SimWorld = p[1]
	EffectQueue.schedule(w, [{"scope": "all", "var": "damage", "op": "set", "value": 50.0}], "test")
	var before: PackedFloat64Array = w.vars["logistics"].duplicate()
	sim.step_month(w)
	var after: PackedFloat64Array = w.vars["logistics"]
	var unchanged := 0
	for i in before.size():
		if is_equal_approx(before[i], after[i]):
			unchanged += 1
	t.check(unchanged == 0, "%d regions did not update" % unchanged)


func test_disaster_causal_chain_food_price_sentiment() -> void:
	var p := _world()
	var sim: Simulation = p[0]
	var w: SimWorld = p[1]
	for _i in 6:
		sim.step_month(w)  # settle
	var i: int = w.region_index["31.71"]  # Kota Jakarta Pusat
	var j: int = w.region_index["53.71"]  # Kota Kupang (control)
	var price0 := w.get_v("price_level", i)
	var sent0 := w.get_v("sentiment", i)
	EffectQueue.schedule(w, [{"scope": "region:31.71", "var": "damage", "op": "add", "value": 60.0}], "test")
	for _k in 3:
		sim.step_month(w)
	t.check(w.get_v("logistics", i) < 50.0, "logistics should drop after damage")
	t.check(w.get_v("price_level", i) > price0, "local price should rise after damage")
	t.check(w.get_v("sentiment", i) < sent0, "local sentiment should fall")
	t.check(w.get_v("sentiment", i) < w.get_v("sentiment", j), "regional divergence: damaged region below control")
	# Recovery: damage decays over time.
	var d1 := w.get_v("damage", i)
	for _k in 12:
		sim.step_month(w)
	t.check(w.get_v("damage", i) < d1 * 0.5, "damage should recover over 12 months")


func test_delayed_and_duration_effects() -> void:
	var p := _world()
	var sim: Simulation = p[0]
	var w: SimWorld = p[1]
	EffectQueue.schedule(w, [{"scope": "province:35", "var": "services", "op": "add", "value": 2.0, "delay": 2, "duration": 3}], "test")
	var i: int = w.region_index["35.78"]  # Kota Surabaya
	var s0 := w.get_v("services", i)
	sim.step_month(w)
	sim.step_month(w)
	t.near(w.get_v("services", i), s0, 0.0001, "no effect before delay elapses")
	for _k in 3:
		sim.step_month(w)
	t.near(w.get_v("services", i), s0 + 6.0, 0.0001, "3 applications of +2 after delay")
	t.check(w.pending_effects.is_empty(), "queue drained")


func test_determinism_same_seed_same_result() -> void:
	var a := _world(42)
	var b := _world(42)
	for w in [a[1], b[1]]:
		EffectQueue.schedule(w, [{"scope": "province:72", "var": "damage", "op": "add", "value": 40.0}], "test")
	for _i in 24:
		a[0].step_month(a[1])
		b[0].step_month(b[1])
	t.check(a[1].vars["sentiment"] == b[1].vars["sentiment"], "identical seeds/inputs must give identical state")


func test_sentiment_state_mapping() -> void:
	var sim: Simulation = _world()[0]
	t.check(sim.sentiment_state(90).id == "sangat_mendukung", "90")
	t.check(sim.sentiment_state(55).id == "stabil", "55")
	t.check(sim.sentiment_state(5).id == "kritis", "5")


func test_sentiment_explanation_names_drivers() -> void:
	var t_ := RegionPanel.explain_sentiment({"harga": -6.0, "kerusakan": -9.0, "kepercayaan": 2.0, "lingkungan": 0.1})
	t.check(t_.begins_with("Tertekan terutama oleh kerusakan dan harga"), t_)
	t.check(t_.contains("Ditopang oleh kepercayaan"), t_)
