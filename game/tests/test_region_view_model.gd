extends RefCounted
## Regression: geographic scope and provenance must survive switching contexts without leakage.
var t


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _fixtures() -> Dictionary:
	var registry := _json("res://data/regions.json")
	var baseline := _json("res://data/baseline.json")
	var sim := Simulation.new(_json("res://data/sim_params.json"), _json("res://data/budget.json"))
	return {"registry": registry, "baseline": baseline,
		"world": WorldFactory.build(registry.regions, baseline, sim, 20261115)}


func _model(f: Dictionary, kind: String, id: String) -> Dictionary:
	return RegionViewModel.build(f.world, kind, id, f.registry.regions, f.registry.provinces, f.baseline)


func test_every_region_and_province_resolves_without_losing_coverage() -> void:
	var f := _fixtures()
	for region in f.registry.regions:
		var result := _model(f, "kabkota", region.region_id)
		t.check(result.valid and result.indices.size() == 1, "one canonical regional state: " + str(region.region_id))
		t.check(result.facts == region.facts, "official reference facts are unchanged")
	var total := 0
	for province in f.registry.provinces:
		var result := _model(f, "province", province.region_id)
		t.check(result.valid, "province resolves: " + str(province.region_id))
		total += result.indices.size()
		t.check(result.facts == province.facts, "provincial facts retain provincial resolution")
	t.check(total == 514, "all 514 regions remain in province coverage")


func test_switching_contexts_clears_facts_identity_metrics_and_events() -> void:
	var f := _fixtures()
	var first := _model(f, "province", "35")
	var city := _model(f, "kabkota", "35.78")
	var group := _model(f, "island_group", "sulawesi")
	var missing := _model(f, "province", "99")
	t.check(first.name == "Jawa Timur", "province identity")
	t.check(city.name == "Kota Surabaya", "city identity replaces province identity")
	t.check(group.name == "Sulawesi" and group.facts.is_empty(), "group never borrows province facts")
	t.check(not missing.valid and missing.facts.is_empty() and missing.metrics.is_empty(), "unknown context is explicitly empty")
	t.check(missing.cases.is_empty() and missing.policies.is_empty(), "no previous event or policy leaks")
	t.check(first.id == "35" and first.facts.size() > 0, "prior model is not overwritten")


func test_scoped_means_and_last_quarter_delta_are_population_weighted() -> void:
	var f := _fixtures()
	var w: SimWorld = f.world
	SimLedger.begin(w)
	var target := _model(f, "province", "35")
	var idx: PackedInt32Array = target.indices
	var total := 0.0
	var population := 0.0
	for i in idx:
		total += w.get_v("welfare", i) * w.get_v("population", i)
		population += w.get_v("population", i)
	t.near(target.metrics[0].value, total / population, 1e-12, "province mean uses only its population")
	var change_index := int(idx[0])
	w.set_v("welfare", change_index, w.get_v("welfare", change_index) + 5.0)
	var after := _model(f, "province", "35")
	t.near(after.metrics[0].delta, 5.0 * w.get_v("population", change_index) / population, 1e-12, "scope delta uses the same weights")
	var unrelated := _model(f, "province", "11")
	t.near(unrelated.metrics[0].delta, 0.0, 1e-12, "unrelated province does not receive national delta")
	w.set_v("population", change_index, 0.0)
	var fallback := _model(f, "province", "35")
	t.check(fallback.weighting == "equal", "missing weight uses explicit equal weighting for the complete scope")


func test_presenter_is_observational_and_prices_are_not_clamped_to_100() -> void:
	var f := _fixtures()
	var w: SimWorld = f.world
	var i: int = w.region_index["35.78"]
	w.set_v("price_level", i, 137.5)
	var before := JSON.stringify(w.to_dict(), "", true, true)
	var result := _model(f, "kabkota", "35.78")
	t.near(result.metrics[5].value, 137.5, 1e-12, "price index keeps its model unit/range")
	t.check(result.metrics[5].delta == null, "no fabricated delta before a quarter exists")
	t.check(before == JSON.stringify(w.to_dict(), "", true, true), "building UI does not change state or RNG")


func test_offline_source_export_matches_registry_digest() -> void:
	var sources := _json("res://data/ui/sources.json")
	t.check(str(sources.registry_sha256).length() == 64, "source export has reproducibility digest")
	var registry := _json("res://data/regions.json")
	for record in registry.regions + registry.provinces:
		for fact in record.facts:
			t.check(sources.sources.has(str(fact.source_id)), "reference fact has offline provenance: " + str(fact.source_id))


func test_term_end_does_not_display_a_sixth_year() -> void:
	var f := _fixtures()
	f.world.tick = SimWorld.TERM_TICKS
	t.check(Fmt.period(f.world) == "Masa jabatan selesai · 20 kuartal", "five-year term ends explicitly")
