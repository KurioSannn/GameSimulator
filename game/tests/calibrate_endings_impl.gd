extends RefCounted
## Ending calibration (not part of the regression suite). Plays full 20-quarter campaigns with
## deterministic strategies and prints the distribution of the ending features, so thresholds in
## game/data/story/endings.json are derived from the model instead of invented.
##   tools/Godot.app/Contents/MacOS/Godot --headless --path game -s res://tests/calibrate_endings.gd

var STRATEGIES: Array = ["neglect", "a", "b", "c", "cheap", "costly", "first", "last"]


func _cost(ch: Dictionary) -> float:
	var c := 0.0
	for e in ch.get("effects", []):
		if e.scope == "national" and e.var == "fiscal_space":
			c += float(e.value) * int(e.get("duration", 1))
	return c


func _pick(strategy: String, c: Dictionary, rng: RandomNumberGenerator) -> String:
	var chs: Array = c.choices
	match strategy:
		"a", "b", "c":
			for ch in chs:
				if ch.choice_id == strategy:
					return strategy
			return str(chs[0].choice_id)
		"cheap":
			var best: Dictionary = chs[0]
			for ch in chs:
				if _cost(ch) > _cost(best):
					best = ch
			return str(best.choice_id)
		"costly":
			var worst: Dictionary = chs[0]
			for ch in chs:
				if _cost(ch) < _cost(worst):
					worst = ch
			return str(worst.choice_id)
	return str(chs[rng.randi() % chs.size()].choice_id)


func _play(strategy: String) -> Dictionary:
	var s := Session.new(ContentDB.sim_params, ContentDB.regions, ContentDB.baseline, ContentDB.cases, 20261115,
		ContentDB.budget, ContentDB.policies)
	Narrative.begin_campaign(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(strategy)
	s.present_next_case()
	var guard := 0
	while not s.world.is_term_over() and guard < 300:
		guard += 1
		if s.pending_case() != "":
			s.decide(s.pending_case(), _pick(strategy, s.cases.cases[s.pending_case()], rng))
			continue
		if not Campaign.can_advance(s) and strategy == "neglect":
			Narrative.ensure(s.world)["quarter_taken"] = s.world.quarter_index()  # counterfactual: nothing taken up
			continue
		if not Campaign.can_advance(s):
			var it := Campaign.items(s)
			var k := 0
			if strategy == "last":
				k = it.size() - 1
			elif strategy.begins_with("rng"):
				k = rng.randi() % it.size()
			Campaign.take(s, it[k].case_id)
			continue
		s.advance_quarter()
	var f := EndingEvaluator.features(s)
	var hist: Array = s.world.story.history
	var min_trust := 1e9
	var min_fiscal := 1e9
	for row in hist:
		min_trust = minf(min_trust, float(row.trust) - float(s.world.story.start.trust))
		min_fiscal = minf(min_fiscal, float(row.fiscal))
	f["min_trust_delta"] = min_trust
	f["min_fiscal"] = min_fiscal
	f["ending"] = EndingEvaluator.evaluate(s, ContentDB.story.endings).id
	return f


func run() -> void:
	for i in 40:
		STRATEGIES.append("rng%d" % (i + 1))
	if ContentDB.cases.is_empty():
		ContentDB.load_all()
	var rows: Array = []
	for st in STRATEGIES:
		var f := _play(st)
		rows.append(f)
		print("%-7s welfare %+6.2f trust %+6.2f services %+6.2f fiscal_end %7.2f min_trust %+6.2f min_fiscal %7.2f kept %d broken %d unattended %d -> %s" % [
			st, f.d_welfare, f.d_trust, f.d_services, f.fiscal_end, f.min_trust_delta, f.min_fiscal,
			f.promises_kept, f.promises_broken, f.unattended, f.ending])
	print("JSON:" + JSON.stringify(rows))
