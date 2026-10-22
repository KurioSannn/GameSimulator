extends SceneTree
## National impact of real flood exposure with NO player intervention (all cases answered "a").
##   Godot --headless --path game -s res://tests/report_national.gd
func _json(p): return JSON.parse_string(FileAccess.get_file_as_string(p))
func _initialize():
	var cases := {}
	for f in DirAccess.get_files_at("res://data/cases"):
		var c: Dictionary = _json("res://data/cases/" + f); cases[c.case_id] = c
	var s := Session.new(_json("res://data/sim_params.json"), _json("res://data/regions.json").regions, _json("res://data/baseline.json"), cases, 11, _json("res://data/budget.json"))
	var w := s.world
	print("| tick | month | regions flooded | mean damage | max damage | national welfare | national sentiment | regions <40 sentiment |")
	print("|---:|---:|---:|---:|---:|---:|---:|---:|")
	s.present_next_case()
	var flooded_total := 0
	while not w.is_term_over():
		if s.pending_case() != "": s.decide(s.pending_case(), "a")
		for _m in 3:
			if w.is_term_over(): break
			var rep := s.sim.step_month(w)
			flooded_total += int(rep.floods)
			if w.tick % 6 == 0:
				var d: PackedFloat64Array = w.vars["damage"]
				var sen: PackedFloat64Array = w.vars["sentiment"]
				var mx := 0.0
				var low := 0
				for i in d.size():
					mx = maxf(mx, d[i])
					if sen[i] < 40.0: low += 1
				print("| %d | %d | %d | %.2f | %.1f | %.2f | %.2f | %d |" % [w.tick, s.sim.month_of(w.tick - 1), rep.floods, w.national_mean("damage"), mx, w.national_mean("welfare"), w.national_mean("sentiment"), low])
		s.present_next_case()
	print("total regional flood events over term: ", flooded_total, " (", "%.2f" % (flooded_total / 397.0 / 5.0), " per exposed region per year)")
	quit()
