extends RefCounted
## Ending calibration (not part of the regression suite). Plays full 20-quarter campaigns with
## deterministic strategies and prints the distribution of the ending features, so thresholds in
## game/data/story/endings.json are derived from the model instead of invented.
##   tools/Godot.app/Contents/MacOS/Godot --headless --path game -s res://tests/calibrate_endings.gd

var STRATEGIES: Array = ["neglect", "a", "b", "c", "cheap", "costly", "first", "last", "strong"]
## Lookahead horizon (quarters) and pillar scales (p75 - p25 spread of the 47 plausible strategies)
## used by the "strong" strategy: an excellent but plausible president who, every quarter, compares
## each open agenda item and each choice by simulating the next quarters, keeps fiscal discipline,
## and hands non-critical items that are about to lapse to the ministries on purpose.
const LOOKAHEAD_Q := 4
const SCALE := {"welfare": 1.15, "trust": 1.95, "services": 2.12, "fiscal": 8.4}
var route: Array = []


func _new_session() -> Session:
	return Session.new(ContentDB.sim_params, ContentDB.regions, ContentDB.baseline, ContentDB.cases, 20261115,
		ContentDB.budget, ContentDB.policies)


func _clone(s: Session) -> Session:
	var c := _new_session()
	c.world.load_dict(s.world.to_dict())
	return c


func _score(s: Session) -> float:
	var p := Narrative.pillar_values(s.world)
	var st: Dictionary = s.world.story.start
	var v: float = (p.welfare - float(st.welfare)) / SCALE.welfare + (p.trust - float(st.trust)) / SCALE.trust \
		+ (p.services - float(st.services)) / SCALE.services + minf(p.fiscal, 20.0) / SCALE.fiscal
	for pid in s.world.story.promises:
		match str(s.world.story.promises[pid].status):
			"kept": v += 0.4
			"broken": v -= 0.6
	return v


## Default continuation inside a lookahead: take the first item, choose "b" (or the first choice).
func _rollout(s: Session, quarters: int) -> void:
	var end_q := mini(s.world.quarter_index() + quarters, 20)
	var guard := 0
	while not s.world.is_term_over() and s.world.quarter_index() < end_q and guard < 60:
		guard += 1
		if s.pending_case() != "":
			var c: Dictionary = s.cases.cases[s.pending_case()]
			var ids: Array = c.choices.map(func(x): return str(x.choice_id))
			s.decide(s.pending_case(), "b" if "b" in ids else ids[0])
			continue
		if not Campaign.can_advance(s):
			Campaign.take(s, Campaign.items(s)[0].case_id)
			continue
		s.advance_quarter()


func _best_choice_for(s: Session, case_id: String) -> String:
	var best := ""
	var best_v := -1e18
	for ch in s.cases.cases[case_id].choices:
		var t := _clone(s)
		t.decide(case_id, str(ch.choice_id))
		_rollout(t, LOOKAHEAD_Q)
		var v := _score(t)
		if v > best_v:
			best_v = v
			best = str(ch.choice_id)
	return best


func _strong_take(s: Session) -> void:
	var best_id := ""
	var best_ch := ""
	var best_v := -1e18
	# a critical crisis whose window is closing is answered first
	var candidates: Array = Campaign.items(s)
	var urgent: Array = candidates.filter(func(it): return int(it.quarters_left) <= 1 and Campaign.is_critical(s.cases.cases[it.case_id]))
	if not urgent.is_empty():
		candidates = urgent
	for it in candidates:
		for ch in s.cases.cases[it.case_id].choices:
			var t := _clone(s)
			Campaign.take(t, it.case_id)
			t.decide(it.case_id, str(ch.choice_id))
			_rollout(t, LOOKAHEAD_Q)
			var v := _score(t)
			if v > best_v:
				best_v = v
				best_id = it.case_id
				best_ch = str(ch.choice_id)
	# deliberate triage: non-critical items about to lapse go to the ministries
	for it in Campaign.items(s):
		if it.case_id != best_id and int(it.quarters_left) <= 1 and Campaign.can_delegate(s, it.case_id):
			Campaign.delegate(s, it.case_id)
			route.append({"q": s.world.quarter_index(), "delegate": it.case_id})
	var e1 := Campaign.take(s, best_id)
	var e2 := s.decide(best_id, best_ch)
	if OS.get_environment("CAL_VERBOSE") != "":
		printerr("q%d take %s/%s %s %s items=%d" % [s.world.quarter_index(), best_id, best_ch, e1, e2, Campaign.items(s).size()])
	route.append({"q": s.world.quarter_index(), "take": best_id, "choice": best_ch})


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
	var s := _new_session()
	Narrative.begin_campaign(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(strategy)
	s.present_next_case()
	var guard := 0
	while not s.world.is_term_over() and guard < 300:
		guard += 1
		if s.pending_case() != "":
			if strategy == "strong":
				var cid := s.pending_case()
				var bc := _best_choice_for(s, cid)
				s.decide(cid, bc)
				route.append({"q": s.world.quarter_index(), "decide": cid, "choice": bc})
				continue
			s.decide(s.pending_case(), _pick(strategy, s.cases.cases[s.pending_case()], rng))
			continue
		if strategy == "strong" and not Campaign.can_advance(s):
			_strong_take(s)
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
	if OS.get_environment("CAL_ONLY") != "":
		STRATEGIES = OS.get_environment("CAL_ONLY").split(",")
	if ContentDB.cases.is_empty():
		ContentDB.load_all()
	var rows: Array = []
	for st in STRATEGIES:
		var f := _play(st)
		rows.append(f)
		print("%-7s welfare %+6.2f trust %+6.2f services %+6.2f fiscal_end %7.2f min_trust %+6.2f kept %d broken %d | missed %d lapsed %d displaced %d covered %d delegated %d -> %s" % [
			st, f.d_welfare, f.d_trust, f.d_services, f.fiscal_end, f.min_trust_delta,
			f.promises_kept, f.promises_broken, f.missed_critical, f.lapsed, f.displaced, f.covered, f.delegated, f.ending])
		if st == "strong":
			print("ROUTE:" + JSON.stringify(route))
	print("JSON:" + JSON.stringify(rows))
