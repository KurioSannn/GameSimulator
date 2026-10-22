class_name WorldFactory
extends RefCounted
## Builds a fresh SimWorld from content exports. Pure (no autoload access) so tests can
## construct worlds from fixtures.


static func build(regions: Array, baseline: Dictionary, sim: Simulation, seed_value: int) -> SimWorld:
	var ids := PackedStringArray()
	var parents := PackedStringArray()
	for r in regions:
		ids.append(str(r["region_id"]))
		parents.append(str(r["parent_region_id"]))
	var w := SimWorld.new()
	w.setup_regions(ids, parents, sim.var_names())
	var bvars: Dictionary = baseline.get("variables", {})
	for v in sim.var_names():
		var spec: Dictionary = bvars.get(v, {})
		var arr: PackedFloat64Array = w.vars[v]
		var values: Variant = spec.get("values")
		if values is Array and (values as Array).size() == ids.size():
			for i in ids.size():
				arr[i] = float(values[i])
		else:
			arr.fill(float(spec.get("default", 0.0)))
		w.vars[v] = arr
	w.seed_rng(seed_value)
	w.start_month = sim.start_month
	var shares := {}
	for sid in sim.budget_cfg.get("sectors", {}):
		shares[sid] = float(sim.budget_cfg.sectors[sid].base_share)
	w.national = {
		"fiscal_space": 50.0,   # 0-100 game index of discretionary fiscal room (SIMULATED; neutral start)
		"budget_level": 1.0,    # spending level relative to baseline (SIMULATED; player-controlled 0.8-1.2)
		"budget_shares": shares,  # sector shares in % (SIMULATED; start = DERIVED base shares)
		"price_pressure": 0.0,  # national commodity price pressure (SIMULATED; 0 = none)
	}
	return w
