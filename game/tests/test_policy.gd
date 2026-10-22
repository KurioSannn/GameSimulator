extends RefCounted
## Policy system tests. Worlds are hazard-free (flood_frequency 0) unless a test needs floods, so
## policy effects are isolated from random hazards. Policy magnitudes are uncalibrated design values.

var t


func _j(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _policies() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/policies"):
		if f.ends_with(".json"):
			var p: Dictionary = _j("res://data/policies/" + f)
			out[p.policy_id] = p
	return out


func _session(extra_policies := {}, cases := {}, seed_value := 9, hazard_free := true) -> Session:
	var pols := _policies()
	pols.merge(extra_policies, true)
	var s := Session.new(_j("res://data/sim_params.json"), _j("res://data/regions.json").regions, _j("res://data/baseline.json"),
		cases, seed_value, _j("res://data/budget.json"), pols)
	if hazard_free:
		var f: PackedFloat64Array = s.world.vars["flood_frequency"]
		f.fill(0.0)
		s.world.vars["flood_frequency"] = f
	return s


func _months(s: Session, n: int) -> void:
	for _i in n:
		s.sim.step_month(s.world)


func _mean(s: Session, v: String, prov: String) -> float:
	var idx := EffectQueue.resolve_scope(s.world, "province:" + prov)
	var acc := 0.0
	for i in idx:
		acc += s.world.get_v(v, i)
	return acc / idx.size()


func test_policies_load_and_are_data_driven() -> void:
	var s := _session()
	t.check(s.policies.policies.size() >= 6, "prototype policies loaded (got %d)" % s.policies.policies.size())
	for id in s.policies.policies:
		var p: Dictionary = s.policies.policies[id]
		t.check(p.fact_class == "FICTIONAL", "%s labeled FICTIONAL (game option, not a real programme)" % id)
		# A cultural mechanic is allowed only with a researched culture record (validated by scripts/validate_all.py too).
		if p.cultural_basis != null:
			# Existence of the referenced record is enforced by scripts/validate_all.py (res:// cannot see research/).
			t.check(str(p.cultural_basis.get("sensitivity_review", "")) != "", "%s: cultural mechanic has a sensitivity review" % id)


func test_prerequisites_are_enforced() -> void:
	var s := _session()
	s.world.national.fiscal_space = 10.0
	t.check(s.policies.can_enact(s.world, "POL-LAYANAN-PUSAT", {"type": "national"}) != "", "fiscal_space < 15 blocks the central programme")
	s.world.national.fiscal_space = 30.0
	t.check(s.policies.can_enact(s.world, "POL-LAYANAN-PUSAT", {"type": "national"}) == "", "allowed when prerequisite holds")


func test_upfront_cost_and_commitment_crowd_out_sectors() -> void:
	var s := _session()
	var fs0 := float(s.world.national.fiscal_space)
	t.check(s.enact_policy("POL-PANGAN-IRIGASI", {"type": "national"}) == "", "enact")
	t.near(float(s.world.national.fiscal_space), fs0 - 2.0, 1e-9, "upfront cost applied immediately")
	t.near(PolicyEngine.total_commitment(s.world), 0.04, 1e-9, "4% of the envelope committed")
	t.near(s.sim.sector_intensity(s.world, "infrastruktur"), 0.96, 1e-9, "commitment crowds out sector programmes (opportunity cost)")
	var infra0 := s.world.national_mean("infrastructure")
	_months(s, 6)
	t.check(s.world.national_mean("infrastructure") < infra0, "crowded-out sectors lose capacity while the policy runs")
	t.near(float(s.world.national.fiscal_space), fs0 - 2.0, 1e-9, "funded within the envelope: no extra deficit at level 1.0")


func test_commitments_beyond_envelope_create_deficit() -> void:
	var s := _session()
	s.set_budget(0.8, s.world.national.budget_shares.duplicate())
	var big: Dictionary = _policies()["POL-SOSIAL-BLT"].duplicate(true)
	big.policy_id = "POL-TEST-BIG"
	big.cost.monthly_commitment = 0.9
	var s2 := _session({"POL-TEST-BIG": big})
	s2.set_budget(0.8, s2.world.national.budget_shares.duplicate())
	s2.enact_policy("POL-TEST-BIG", {"type": "national"})
	var fs0 := float(s2.world.national.fiscal_space)
	_months(s2, 1)
	t.near(float(s2.world.national.fiscal_space), fs0 + 5.0 * (1.0 - 0.9), 1e-9, "spending = max(level, commitment) drives fiscal space")
	t.near(s2.sim.sector_intensity(s2.world, "layanan"), 0.0, 1e-9, "no money left for sector programmes")


func test_delayed_implementation() -> void:
	var s := _session()
	s.enact_policy("POL-PANGAN-IRIGASI", {"type": "province", "id": "32"})
	var f0 := _mean(s, "food_capacity", "32")
	t.check(PolicyEngine.status_of(s.world, "POL-PANGAN-IRIGASI") == PolicyEngine.IMPLEMENTING, "implementing")
	_months(s, 6)
	t.near(_mean(s, "food_capacity", "32"), f0 * pow(1.0 + 0.01 * (s.sim.sector_intensity(s.world, "pangan") - 1.0), 6), 1e-6, "no policy effect during 6-month implementation (only sector budget drift)")
	t.check(PolicyEngine.status_of(s.world, "POL-PANGAN-IRIGASI") == PolicyEngine.ACTIVE, "active after implementation")
	_months(s, 12)
	t.check(_mean(s, "food_capacity", "32") > f0 * 1.01, "food capacity rises once active")


func test_regional_targeting_and_eligibility_filter() -> void:
	var s := _session()
	s.enact_policy("POL-LAYANAN-PUSAT", {"type": "province", "id": "73"})
	_months(s, 10)
	t.check(_mean(s, "services", "73") > _mean(s, "services", "33") + 1.0, "targeted province gains, others do not")
	var d := _session({}, {}, 9, false)
	var idx := d.policies.resolve_target(d.world, d.policies.policies["POL-KEBENCANAAN-DRAINASE"], {"type": "national"})
	t.check(idx.size() > 0 and idx.size() < 514, "drainage eligible only where flood_frequency >= 3 (got %d regions)" % idx.size())
	for i in idx:
		if d.world.get_v("flood_frequency", i) < 3.0:
			t.check(false, "ineligible region targeted")
			return
	var isl := d.policies.resolve_target(d.world, d.policies.policies["POL-INFRA-JALAN"], {"type": "island_group", "id": "papua"})
	t.check(isl.size() > 0 and isl.size() < 60, "island-group targeting resolves Papua regions (%d)" % isl.size())
	t.check(d.policies.can_enact(d.world, "POL-INFRA-JALAN", {"type": "kabkota", "id": "99.99"}) != "", "unknown region rejected")


func test_national_policy_has_regional_differences() -> void:
	var s := _session()
	var lo: int = s.world.region_index["91.71"]
	var hi: int = s.world.region_index["31.71"]
	s.world.set_v("infrastructure", lo, 20.0)
	s.world.set_v("infrastructure", hi, 80.0)
	s.enact_policy("POL-INFRA-JALAN", {"type": "national"})
	var lo0 := s.world.get_v("infrastructure", lo)
	var hi0 := s.world.get_v("infrastructure", hi)
	_months(s, 24)
	var dlo := s.world.get_v("infrastructure", lo) - lo0
	var dhi := s.world.get_v("infrastructure", hi) - hi0
	t.check(dlo > dhi * 2.0, "same national policy, larger gain where roads are worst (%f vs %f)" % [dlo, dhi])


func test_mutually_exclusive_policies() -> void:
	var s := _session()
	t.check(s.enact_policy("POL-LAYANAN-DAERAH", {"type": "national"}) == "", "first delivery model enacted")
	t.check(s.enact_policy("POL-LAYANAN-PUSAT", {"type": "national"}) != "", "incompatible model refused while the first runs")
	t.check(s.enact_policy("POL-LAYANAN-DAERAH", {"type": "national"}) != "", "same policy cannot run twice")


func test_cooldown_after_end() -> void:
	var s := _session()
	s.enact_policy("POL-SOSIAL-BLT", {"type": "national"})
	_months(s, 6)
	t.check(PolicyEngine.status_of(s.world, "POL-SOSIAL-BLT") == PolicyEngine.ENDED, "ended after 6 months")
	t.check(s.enact_policy("POL-SOSIAL-BLT", {"type": "national"}) != "", "refused during 12-month cooldown")
	_months(s, 12)
	t.check(s.enact_policy("POL-SOSIAL-BLT", {"type": "national"}) == "", "allowed after cooldown")
	t.check(int(s.world.policy_state["POL-SOSIAL-BLT"].count) == 2, "enactment count tracked")


func test_causal_chain_irrigation_to_prices() -> void:
	var s := _session()
	var drought := func(w: SimWorld):
		var f: PackedFloat64Array = w.vars["food_capacity"]
		f.fill(0.8)  # explicit test fixture: food-deficit world, not a real statistic
		w.vars["food_capacity"] = f
	drought.call(s.world)
	var c := _session()
	drought.call(c.world)
	s.enact_policy("POL-PANGAN-IRIGASI", {"type": "national"})
	_months(s, 30)
	_months(c, 30)
	t.check(s.world.national_mean("food_supply") > c.world.national_mean("food_supply"), "irrigation -> more food supply")
	t.check(s.world.national_mean("price_level") < c.world.national_mean("price_level"), "-> lower prices")
	t.check(s.world.national_mean("welfare") > c.world.national_mean("welfare") - 0.5, "-> welfare not worse despite crowding out")


func test_policy_persists_across_save_load() -> void:
	var a := _session({}, {}, 9, false)
	a.enact_policy("POL-KEBENCANAAN-DRAINASE", {"type": "province", "id": "31"})
	a.enact_policy("POL-INFRA-JALAN", {"type": "island_group", "id": "sulawesi"})
	_months(a, 5)
	var svc := SaveService.new("user://test_saves_policy")
	t.check(svc.save("p", "p", a.world.to_dict()) == "", "save")
	var b := _session({}, {}, 9, false)
	t.check(b.world.load_dict(svc.load_slot("p").payload) == "", "load")
	t.check(b.world.policy_state == a.world.policy_state, "policy state restored")
	t.near(PolicyEngine.total_commitment(b.world), PolicyEngine.total_commitment(a.world), 0.0, "commitments restored")
	_months(a, 30)
	_months(b, 30)
	t.check(a.world.vars["flood_protection"] == b.world.vars["flood_protection"], "identical policy effects after reload")
	t.check(a.world.vars["infrastructure"] == b.world.vars["infrastructure"], "identical infrastructure after reload")


func test_policy_changes_case_eligibility() -> void:
	var fixture_case := {"case_id": "CASE-TEST-POL", "trigger": {"conditions": {"policy_active": "POL-SOSIAL-BLT"}, "weight": 1}, "choices": []}
	var s := _session({}, {"CASE-TEST-POL": fixture_case})
	t.check(not ("CASE-TEST-POL" in s.cases.eligible(s.world)), "not eligible before the policy")
	s.enact_policy("POL-SOSIAL-BLT", {"type": "national"})
	t.check("CASE-TEST-POL" in s.cases.eligible(s.world), "eligible while the policy runs")
	t.check(Conditions.eval(s.world, {"policy_enacted": "POL-SOSIAL-BLT"}), "policy_enacted condition")


func test_determinism_and_bounded_uncertainty() -> void:
	var a := _session({}, {}, 33)
	var b := _session({}, {}, 33)
	for s in [a, b]:
		s.enact_policy("POL-LAYANAN-DAERAH", {"type": "national"})
		_months(s, 24)
	t.check(a.world.vars["services"] == b.world.vars["services"], "same seed + state -> identical outcome")
	var m := float(a.world.policy_state["POL-LAYANAN-DAERAH"].multiplier)
	t.check(m >= 0.65 and m <= 1.35, "uncertainty multiplier within +/-35%% (got %f)" % m)


func test_v2_save_migrates_without_policies() -> void:
	var s := _session()
	var d: Dictionary = s.world.to_dict()
	d.schema = 2
	d.erase("policy_state")
	var q := _session()
	t.check(q.world.load_dict(JSON.parse_string(JSON.stringify(d))) == "", "v2 save loads")
	t.check(q.world.policy_state.is_empty(), "no policies in migrated save")
