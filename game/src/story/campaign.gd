class_name Campaign
extends RefCounted
## Quarterly agenda for the main campaign (GDD "Agenda Kuartal"). Replaces the silent
## "one case per quarter by priority" pick for interactive play:
##   - every case whose trigger conditions hold is OPENED on the agenda (up to MAX_OPEN at a time;
##     the rest wait in a visible queue in deterministic order, nothing is dropped);
##   - each quarter the president takes up ONE agenda item (the major decision of the quarter);
##   - an item left on the agenda for its window (default 3 quarters) is handled without the president:
##     its shock happens anyway, plus a small trust cost, it is logged, journaled and narrated;
##   - at the end of the term every case that never opened is reported, not hidden.
## Headless test sessions keep the legacy Session.present_next_case() path (agenda_mode false), so the
## golden masters of the original cases stay valid.

const MAX_OPEN := 3
const DEFAULT_WINDOW_Q := 3
const FOLLOWUP_WINDOW_Q := 2
## Design values (calibrated 2026-11-23, see research/reports/2026-11-23_STORY_CAMPAIGN_REPORT.md): an
## unattended crisis lacks a coordinated response, so affected regions lose trust, welfare and services
## for months. Before calibration (-1 trust only) neglecting every agenda item scored like governing.
const UNATTENDED_TRUST := -3.0
const UNATTENDED_TRUST_NATIONAL := -1.2
const UNATTENDED_WELFARE := -0.4   # per month for UNATTENDED_MONTHS
const UNATTENDED_SERVICES := -0.4
const UNATTENDED_MONTHS := 6
const SKIP_CHOICE := "_tunda"
const DELEGATE_CHOICE := "_delegasi"

## Agenda outcome categories (D-093). Expiry is not one thing: an active president has one major
## decision per quarter and more issues than slots, so most lapses are displacement, not neglect.
const OUTCOME_ADDRESSED := "ditangani"            # the president decided it
const OUTCOME_DELEGATED := "didelegasikan"        # handed to the ministries on purpose (non-critical only)
const OUTCOME_COVERED := "teratasi_kebijakan_lain"  # lapsed, but a decision in the same province covered it
const OUTCOME_DISPLACED := "tergeser"             # lapsed while the president handled other critical issues
const OUTCOME_LAPSED := "terlewat"                # lapsed in a quarter where nothing was taken up
const OUTCOME_MISSED_CRITICAL := "kewajiban_terlewat"  # a critical crisis lapsed while lesser items were taken
const OUTCOME_LABELS := {
	"ditangani": "Ditangani Presiden", "didelegasikan": "Diserahkan ke kementerian",
	"teratasi_kebijakan_lain": "Teratasi lewat keputusan lain", "tergeser": "Tergeser krisis lain",
	"terlewat": "Terlewat tanpa tindakan", "kewajiban_terlewat": "Krisis besar yang terlewat",
}
## Share of the unattended cost that lands, per outcome (design values, D-093).
const OUTCOME_COST := {
	"didelegasikan": {"trust": 0.35, "loss": 0.5}, "teratasi_kebijakan_lain": {"trust": 0.3, "loss": 0.3},
	"tergeser": {"trust": 0.5, "loss": 0.75}, "terlewat": {"trust": 1.0, "loss": 1.0},
	"kewajiban_terlewat": {"trust": 1.0, "loss": 1.0},
}
const CRITICAL_DAMAGE := 8.0


static func enabled(world: SimWorld) -> bool:
	return bool(world.story.get("agenda_mode", false))


## Deterministic order: story priority (high first), then trigger month, then id.
static func _order(cases: Dictionary, ids: Array) -> Array:
	var out := ids.duplicate()
	out.sort_custom(func(a, b):
		var pa := float(cases[a].get("trigger", {}).get("story_priority", 0))
		var pb := float(cases[b].get("trigger", {}).get("story_priority", 0))
		if pa != pb:
			return pa > pb
		var ta := _trigger_tick(cases[a])
		var tb := _trigger_tick(cases[b])
		if ta != tb:
			return ta < tb
		return str(a) < str(b))
	return out


static func _trigger_tick(c: Dictionary) -> int:
	for sub in c.get("trigger", {}).get("conditions", {}).get("all", []):
		if sub is Dictionary and sub.has("tick"):
			return int(sub.value)
	return 0


## Cases whose conditions hold but that are neither on the agenda nor already handled.
static func waiting(session: Session) -> Array:
	var s := Narrative.ensure(session.world)
	var ids: Array = session.cases.eligible(session.world).filter(func(id): return not s.agenda.has(id))
	return _order(session.cases.cases, ids)


static func refresh(session: Session) -> Array:
	var s := Narrative.ensure(session.world)
	var opened: Array = []
	for id in waiting(session):
		if s.agenda.size() >= MAX_OPEN:
			break
		s.agenda[id] = {"opened_tick": session.world.tick}
		opened.append(id)
		SimLedger.log_event(session.world, SimLedger.scheduled_entry(session.world, "agenda", "case:%s/agenda" % id,
			{"case_id": id, "title": str(session.cases.cases[id].get("title", id))}))
	return opened


static func window_quarters(c: Dictionary) -> int:
	var w := int(c.get("story", {}).get("agenda", {}).get("window_quarters", 0))
	if w > 0:
		return w
	return FOLLOWUP_WINDOW_Q if str(c.get("class", "")) == "secondary_consequence" else DEFAULT_WINDOW_Q


## Agenda cards for the UI: [{case_id, opened_tick, quarters_left}], deterministic order.
static func items(session: Session) -> Array:
	var s := Narrative.ensure(session.world)
	var out: Array = []
	for id in _order(session.cases.cases, s.agenda.keys()):
		var c: Dictionary = session.cases.cases[id]
		var age_q := (session.world.tick - int(s.agenda[id].opened_tick)) / SimWorld.TICKS_PER_QUARTER
		out.append({"case_id": id, "opened_tick": int(s.agenda[id].opened_tick),
			"quarters_left": maxi(1, window_quarters(c) - age_q)})
	return out


static func taken_this_quarter(world: SimWorld) -> bool:
	return int(Narrative.ensure(world).quarter_taken) == world.quarter_index()


## The president takes up an agenda item: its event happens (trigger effects) and the decision opens.
static func take(session: Session, case_id: String) -> String:
	var s := Narrative.ensure(session.world)
	if not s.agenda.has(case_id):
		return "Agenda %s tidak tersedia." % case_id
	if session.pending_case() != "":
		return "Selesaikan keputusan yang sedang berjalan terlebih dahulu."
	if taken_this_quarter(session.world):
		return "Keputusan besar kuartal ini sudah diambil."
	s.agenda.erase(case_id)
	s["quarter_taken"] = session.world.quarter_index()
	s.taken_log.append({"q": session.world.quarter_index(), "case": case_id,
		"critical": is_critical(session.cases.cases[case_id])})
	s.outcomes[case_id] = OUTCOME_ADDRESSED
	session.cases.trigger(session.world, case_id)
	SimLedger.log_event(session.world, SimLedger.scheduled_entry(session.world, "case", "case:%s/trigger" % case_id,
		{"case_id": case_id, "title": str(session.cases.cases[case_id].get("title", case_id))}))
	Narrative.queue(session.world, {"kind": "opening", "case": case_id})
	return ""


## True when the quarter may advance: no open decision and, if the agenda has items, one was taken.
static func can_advance(session: Session) -> bool:
	if session.pending_case() != "" or session.world.is_term_over():
		return false
	var s := Narrative.ensure(session.world)
	return s.agenda.is_empty() or taken_this_quarter(session.world)


static func block_reason(session: Session) -> String:
	if session.world.is_term_over():
		return "Masa bakti telah selesai."
	if session.pending_case() != "":
		return "Ada keputusan yang belum ditetapkan."
	if not can_advance(session):
		return "Pilih satu agenda untuk ditangani kuartal ini."
	return ""


## A critical issue is one a president is expected to answer personally: a disaster with heavy damage
## or an episode flagged critical (deadly outbreaks). Critical items cannot be delegated.
static func is_critical(c: Dictionary) -> bool:
	var flag: Variant = c.get("story", {}).get("agenda", {}).get("critical", null)
	if flag != null:
		return bool(flag)
	for e in c.get("on_trigger_effects", []):
		if str(e.get("var", "")) == "damage" and float(e.get("value", 0.0)) >= CRITICAL_DAMAGE:
			return true
	return false


static func can_delegate(session: Session, case_id: String) -> bool:
	var s := Narrative.ensure(session.world)
	return s.agenda.has(case_id) and not is_critical(session.cases.cases[case_id])


## The president hands a non-critical item to the ministries on purpose. Does not use the quarter's
## decision; the event still happens, at a reduced unattended cost.
static func delegate(session: Session, case_id: String) -> String:
	if not can_delegate(session, case_id):
		return "Krisis besar ini membutuhkan keputusan Presiden."
	var s := Narrative.ensure(session.world)
	var c: Dictionary = session.cases.cases[case_id]
	s.agenda.erase(case_id)
	_resolve_without_president(session, case_id, c, OUTCOME_DELEGATED)
	return ""


static func _provinces(c: Dictionary) -> Dictionary:
	var out := {}
	for r in c.get("focus_regions", []):
		out[str(r).substr(0, 2)] = true
	return out


## Classifies a lapsed item from what the president actually did while it was open.
static func classify_lapse(session: Session, case_id: String, opened_tick: int) -> String:
	var s := Narrative.ensure(session.world)
	var c: Dictionary = session.cases.cases[case_id]
	var q0 := opened_tick / SimWorld.TICKS_PER_QUARTER
	var q1 := session.world.quarter_index()
	var mine := _provinces(c)
	if not mine.is_empty():
		for other in session.world.case_state:
			var st: Dictionary = session.world.case_state[other]
			var ch := str(st.get("choice_id", ""))
			if other == case_id or ch == "" or ch == SKIP_CHOICE or ch == DELEGATE_CHOICE:
				continue
			if int(st.get("decided_tick", -1)) < opened_tick or not session.cases.cases.has(other):
				continue
			for p in _provinces(session.cases.cases[other]):
				if mine.has(p):
					return OUTCOME_COVERED
	var by_q := {}
	for row in s.taken_log:
		by_q[int(row.q)] = bool(row.critical)
	var idle := false
	var lesser := false
	for q in range(q0, q1):
		if not by_q.has(q):
			idle = true
		elif not by_q[q]:
			lesser = true
	if is_critical(c) and (idle or lesser):
		return OUTCOME_MISSED_CRITICAL
	return OUTCOME_LAPSED if idle else OUTCOME_DISPLACED


## Items whose window has passed are handled without a presidential decision (never silently).
static func expire_due(session: Session) -> Array:
	var s := Narrative.ensure(session.world)
	var expired: Array = []
	for item in items(session):
		var id: String = item.case_id
		var c: Dictionary = session.cases.cases[id]
		var age := session.world.tick - int(item.opened_tick)
		if age < window_quarters(c) * SimWorld.TICKS_PER_QUARTER:
			continue
		var outcome := classify_lapse(session, id, int(item.opened_tick))
		s.agenda.erase(id)
		_resolve_without_president(session, id, c, outcome)
		expired.append(id)
	return expired


static func _resolve_without_president(session: Session, id: String, c: Dictionary, outcome: String) -> void:
	var s := Narrative.ensure(session.world)
	var cost: Dictionary = OUTCOME_COST.get(outcome, OUTCOME_COST.terlewat)
	var effects: Array = c.get("on_trigger_effects", []).duplicate(true)
	var custom: Array = c.get("story", {}).get("agenda", {}).get("unattended_effects", [])
	if not custom.is_empty():
		effects.append_array(custom)
	else:
		var scope := "all" if c.get("focus_regions", []).is_empty() else "regions:" + ",".join(c.focus_regions)
		var national := scope == "all"
		var k_t := float(cost.trust)
		var k_l := float(cost.loss) * (0.4 if national else 1.0)
		effects.append({"scope": scope, "var": "trust", "op": "add", "value": k_t * (UNATTENDED_TRUST_NATIONAL if national else UNATTENDED_TRUST)})
		effects.append({"scope": scope, "var": "welfare", "op": "add", "value": UNATTENDED_WELFARE * k_l, "duration": UNATTENDED_MONTHS})
		effects.append({"scope": scope, "var": "services", "op": "add", "value": UNATTENDED_SERVICES * k_l, "duration": UNATTENDED_MONTHS})
	var choice := DELEGATE_CHOICE if outcome == OUTCOME_DELEGATED else SKIP_CHOICE
	EffectQueue.schedule(session.world, effects, "case:%s/choice:%s" % [id, choice])
	session.world.case_state[id] = {"status": CaseEngine.STATUS_RESOLVED, "triggered_tick": session.world.tick,
		"decided_tick": session.world.tick, "choice_id": choice, "count": 1,
		"history": [{"tick": session.world.tick, "choice": choice}]}
	s.outcomes[id] = outcome
	if outcome != OUTCOME_DELEGATED:
		s.expired.append(id)
	SimLedger.log_event(session.world, SimLedger.scheduled_entry(session.world, "decision", "case:%s/choice:%s" % [id, choice],
		{"case_id": id, "choice_id": choice, "title": str(c.get("title", id)),
		"choice_label": str(OUTCOME_LABELS.get(outcome, outcome)), "fact_class": "SIMULATED"}))
	var line := str(c.get("story", {}).get("agenda", {}).get("if_postponed",
		"Masalah ini ditangani kementerian teknis tanpa arahan langsung Presiden. Warga di daerah merasakannya."))
	Narrative.journal(session.world, "tertunda", "%s (%s)" % [str(c.get("title", id)), str(OUTCOME_LABELS.get(outcome, outcome)).to_lower()], line, id)
	if c.get("story", {}).has("unattended"):
		Narrative.queue(session.world, {"kind": "unattended", "case": id})


## Counts per outcome category (ending, Buku Kisah, calibration).
static func outcome_counts(world: SimWorld) -> Dictionary:
	var s := Narrative.ensure(world)
	var out := {}
	for k in OUTCOME_LABELS:
		out[k] = 0
	for id in s.outcomes:
		out[str(s.outcomes[id])] = int(out.get(str(s.outcomes[id]), 0)) + 1
	return out


## Cases never opened during the term (reported in the ending; replayable in Kumpulan Kisah).
static func never_opened(session: Session) -> Array:
	var s := Narrative.ensure(session.world)
	var out: Array = []
	for id in session.cases.cases:
		var c: Dictionary = session.cases.cases[id]
		if str(c.get("class", "")) != "major_historical":
			continue
		if session.world.case_state.has(id) or s.agenda.has(id):
			continue
		out.append(id)
	out.sort()
	return out
