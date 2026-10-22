extends SceneTree
## Outcome matrix for the reference case: first decision x response to recurring floods.
##   Godot --headless --path game -s res://tests/report_case0001.gd
## Prints a Markdown table (paste into reports). Same seed everywhere: hazards are identical across
## rows (counter-based RNG), so differences are caused by decisions only.

const FOCUS := ["31.71", "31.72", "31.73", "31.74", "31.75", "32.01", "36.02"]


func _json(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _cases() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		if f.ends_with(".json"):
			var c: Dictionary = _json("res://data/cases/" + f)
			out[c.case_id] = c
	return out


func play(first: String, recurring: String, follow: String, budget_disaster := 0.0) -> Dictionary:
	var s := Session.new(_json("res://data/sim_params.json"), _json("res://data/regions.json").regions,
		_json("res://data/baseline.json"), _cases(), 11, _json("res://data/budget.json"))
	if budget_disaster > 0.0:
		var shares: Dictionary = s.world.national.budget_shares.duplicate()
		shares.kebencanaan += budget_disaster
		shares.layanan -= budget_disaster
		s.set_budget(1.0, shares)
	var idx: Array = FOCUS.map(func(id): return s.world.region_index[id])
	var flood_sum := 0.0
	var floods := 0
	var min_sent := 100.0
	var seq: Array = []
	s.present_next_case()
	while not s.world.is_term_over():
		var pend := s.pending_case()
		if pend != "":
			seq.append(pend)
			var ch := first if pend == "CASE-0001" else (recurring if pend == "CASE-0001-R" else follow)
			s.decide(pend, ch)
		for _m in 3:
			if s.world.is_term_over():
				break
			s.sim.step_month(s.world)
			for i in idx:
				var f := s.world.get_v("flood_damage_last", i)
				flood_sum += f
				floods += 1 if f > 0.0 else 0
			min_sent = minf(min_sent, s.world.get_v("sentiment", idx[0]))
		s.present_next_case()
	var w := s.world
	var mean := func(v): return idx.reduce(func(a, i): return a + w.get_v(v, i), 0.0) / idx.size()
	return {"floods": floods, "flood_damage": flood_sum, "end_sent": mean.call("sentiment"),
		"min_sent_jp": min_sent, "end_prot": mean.call("flood_protection"), "end_welfare": mean.call("welfare"),
		"fiscal": float(w.national.fiscal_space), "nat_sent": w.national_mean("sentiment"), "seq": seq.size()}


func _initialize() -> void:
	print("| CASE-0001 | recurring (R) | budget | flood events (7 regions) | cum. flood damage | end protection | end welfare | end sentiment (focus) | min sentiment (Jkt Pusat) | fiscal space | national sentiment | cases seen |")
	print("|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	for first in ["a", "b", "c"]:
		for rec in ["a", "b", "c"]:
			_row(first, rec, 0.0)
	_row("c", "b", 5.0)
	_row("a", "a", 5.0)
	quit(0)


func _row(first: String, rec: String, bd: float) -> void:
	var r := play(first, rec, "a", bd)
	print("| %s | %s | %s | %d | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.2f | %d |" % [first, rec,
		"+%d%% kebencanaan" % bd if bd > 0 else "baseline", r.floods, r.flood_damage, r.end_prot, r.end_welfare,
		r.end_sent, r.min_sent_jp, r.fiscal, r.nat_sent, r.seq])
