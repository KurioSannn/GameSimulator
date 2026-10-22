extends RefCounted
## Budget system: equilibrium at baseline, sector effects, fiscal drain, validation, RNG.

var t


func _session() -> Session:
	var j := func(p): return JSON.parse_string(FileAccess.get_file_as_string(p))
	return Session.new(j.call("res://data/sim_params.json"), j.call("res://data/regions.json").regions,
		j.call("res://data/baseline.json"), {}, 5, j.call("res://data/budget.json"))


func _base_shares(s: Session) -> Dictionary:
	return s.world.national.budget_shares.duplicate()


func test_baseline_budget_is_equilibrium() -> void:
	var s := _session()
	var infra0 := s.world.national_mean("infrastructure")
	for _m in 24:
		s.sim.step_month(s.world)
	t.near(s.world.national_mean("infrastructure"), infra0, 1e-9, "no drift at baseline funding")
	t.near(float(s.world.national.fiscal_space), 50.0, 1e-9, "fiscal space stable at level 1.0")


func test_overspending_drains_fiscal_space_and_is_capped() -> void:
	var s := _session()
	t.check(s.set_budget(1.2, _base_shares(s)) == "", "level 1.2 allowed")
	for _m in 12:
		s.sim.step_month(s.world)
	t.near(float(s.world.national.fiscal_space), 50.0 - 12.0 * 5.0 * 0.2, 1e-9, "fiscal drains 1/month at level 1.2")
	t.check(s.world.national_mean("infrastructure") > 50.0, "higher level raises sector capacity")
	for _m in 60:
		s.sim.step_month(s.world)
	t.near(float(s.world.national.fiscal_space), 0.0, 1e-9, "fiscal space floors at 0")
	t.near(float(s.world.national.budget_level), 1.0, 1e-9, "overspending forced back to 1.0 when fiscal space is exhausted")
	t.check(s.set_budget(1.1, _base_shares(s)) != "", "cannot raise level with no fiscal space")


func test_disaster_sector_builds_protection_only_where_exposed() -> void:
	var s := _session()
	var w := s.world
	var i: int = w.region_index["31.71"]
	var j: int = w.region_index["51.71"]
	w.set_v("flood_frequency", i, 8.0)
	w.set_v("flood_frequency", j, 0.0)  # forced 0 only to test the spending weight
	var sh := _base_shares(s)
	sh.kebencanaan += 10.0
	sh.layanan -= 10.0
	t.check(s.set_budget(1.0, sh) == "", "reallocation accepted")
	var p0 := w.get_v("flood_protection", i)
	var q0 := w.get_v("flood_protection", j)
	for _m in 12:
		s.sim.step_month(w)
	t.check(w.get_v("flood_protection", i) > p0 + 5.0, "protection grows where exposed")
	t.near(w.get_v("flood_protection", j), q0, 1e-9, "no protection spending where flood frequency is 0")
	t.check(w.national_mean("services") < 50.0, "reallocation away from services has a cost")


func test_set_budget_validation() -> void:
	var s := _session()
	t.check(s.set_budget(1.5, _base_shares(s)) != "", "level out of range rejected")
	var bad := _base_shares(s)
	bad.pangan += 5.0
	t.check(s.set_budget(1.0, bad) != "", "shares must sum to 100")
	bad = _base_shares(s)
	bad.erase("pangan")
	t.check(s.set_budget(1.0, bad) != "", "missing sector rejected")


func test_counter_rng_is_deterministic_and_uniform() -> void:
	t.check(SimRng.u01(7, 3, 100, 1) == SimRng.u01(7, 3, 100, 1), "same inputs, same draw")
	t.check(SimRng.u01(7, 3, 100, 1) != SimRng.u01(7, 3, 101, 1), "different region, different draw")
	var sum := 0.0
	var lo := 1.0
	var hi := 0.0
	for k in 20000:
		var u := SimRng.u01(1, k / 514, k % 514, 1)
		sum += u
		lo = minf(lo, u)
		hi = maxf(hi, u)
	t.near(sum / 20000.0, 0.5, 0.01, "mean ~0.5")
	t.check(lo >= 0.0 and hi < 1.0, "range [0,1)")
