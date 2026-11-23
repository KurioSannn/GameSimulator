class_name EndingEvaluator
extends RefCounted
## Balanced end-of-term assessment (GDD "Akhir Masa Bakti"). Not one score: each pillar is rated
## good / fair / poor against thresholds calibrated from deterministic playthroughs
## (game/data/story/endings.json "calibration"), then combined with promises, unattended crises and
## sustained crisis quarters. A single bad decision cannot end the game; a crisis must persist.

const ARCHETYPES := ["warisan_besar", "nusantara_menguat", "pemerintahan_bertahan", "janji_belum_selesai", "krisis_mandat"]


## features: everything the ending and its retrospective need, computed from actual state.
static func features(session: Session) -> Dictionary:
	var s := Narrative.ensure(session.world)
	var p := Narrative.pillars(session)
	var kept := 0
	var broken := 0
	for pid in s.promises:
		match str(s.promises[pid].status):
			"kept": kept += 1
			"broken": broken += 1
	var decided := 0
	for id in session.world.case_state:
		var ch := str(session.world.case_state[id].get("choice_id", ""))
		if ch != "" and ch != Campaign.SKIP_CHOICE:
			decided += 1
	return {
		"d_welfare": float(p.welfare.delta), "d_trust": float(p.trust.delta), "d_services": float(p.services.delta),
		"fiscal_end": float(p.fiscal.value), "d_fiscal": float(p.fiscal.delta),
		"promises_kept": kept, "promises_broken": broken, "promises_open": s.promises.size() - kept - broken,
		"unattended": (s.expired as Array).size(), "decided": decided,
		"crisis_quarters": 0,
		"mean_damage": session.world.national_mean("damage"),
	}


static func rate(value: float, good: float, poor: float) -> String:
	if value >= good:
		return "good"
	if value <= poor:
		return "poor"
	return "fair"


## Returns {"id", "ratings": {pillar: good|fair|poor}, "features"}.
static func evaluate(session: Session, cfg: Dictionary) -> Dictionary:
	var f := features(session)
	var th: Dictionary = cfg.get("thresholds", {})
	var s := Narrative.ensure(session.world)
	var crisis_trust := float(th.get("crisis_trust_delta", -6.0))
	var crisis_fiscal := float(th.get("crisis_fiscal_level", -20.0))
	var start: Dictionary = s.get("start", {})
	var crisis_q := 0
	for row in s.history:
		var trust_d := float(row.get("trust", 0.0)) - float(start.get("trust", row.get("trust", 0.0)))
		if trust_d <= crisis_trust or float(row.get("fiscal", 0.0)) <= crisis_fiscal:
			crisis_q += 1
	f["crisis_quarters"] = crisis_q
	var ratings := {
		"welfare": rate(f.d_welfare, float(th.get("welfare_good", 1.0)), float(th.get("welfare_poor", -1.0))),
		"trust": rate(f.d_trust, float(th.get("trust_good", 1.0)), float(th.get("trust_poor", -2.0))),
		"services": rate(f.d_services, float(th.get("services_good", 1.0)), float(th.get("services_poor", -1.0))),
		"fiscal": rate(f.fiscal_end, float(th.get("fiscal_good", 20.0)), float(th.get("fiscal_poor", 0.0))),
	}
	var goods := ratings.values().count("good")
	var poors := ratings.values().count("poor")
	var settled := int(f.promises_kept) + int(f.promises_broken)
	var kept_ratio := 1.0 if settled == 0 else float(f.promises_kept) / settled
	var id := "pemerintahan_bertahan"
	if crisis_q >= int(th.get("crisis_min_quarters", 4)) and ratings.trust == "poor":
		id = "krisis_mandat"
	elif goods == 4 and kept_ratio >= float(th.get("legacy_promise_ratio", 0.6)):
		id = "warisan_besar"
	elif goods >= 2 and poors == 0:
		id = "nusantara_menguat"
	elif (ratings.welfare == "good" or ratings.services == "good") and (ratings.fiscal == "poor" or kept_ratio < 0.5):
		id = "janji_belum_selesai"
	return {"id": id, "ratings": ratings, "features": f, "kept_ratio": kept_ratio}
