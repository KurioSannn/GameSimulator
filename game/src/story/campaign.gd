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
const UNATTENDED_TRUST := -1.0
const UNATTENDED_TRUST_NATIONAL := -0.3
const SKIP_CHOICE := "_tunda"


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
		s.agenda.erase(id)
		var effects: Array = c.get("on_trigger_effects", []).duplicate(true)
		var custom: Array = c.get("story", {}).get("agenda", {}).get("unattended_effects", [])
		if not custom.is_empty():
			effects.append_array(custom)
		elif c.get("focus_regions", []).is_empty():
			effects.append({"scope": "all", "var": "trust", "op": "add", "value": UNATTENDED_TRUST_NATIONAL})
		else:
			effects.append({"scope": "regions:" + ",".join(c.focus_regions), "var": "trust", "op": "add", "value": UNATTENDED_TRUST})
		EffectQueue.schedule(session.world, effects, "case:%s/choice:%s" % [id, SKIP_CHOICE])
		session.world.case_state[id] = {"status": CaseEngine.STATUS_RESOLVED, "triggered_tick": session.world.tick,
			"decided_tick": session.world.tick, "choice_id": SKIP_CHOICE, "count": 1,
			"history": [{"tick": session.world.tick, "choice": SKIP_CHOICE}]}
		s.expired.append(id)
		SimLedger.log_event(session.world, SimLedger.scheduled_entry(session.world, "decision", "case:%s/choice:%s" % [id, SKIP_CHOICE],
			{"case_id": id, "choice_id": SKIP_CHOICE, "title": str(c.get("title", id)),
			"choice_label": "Tidak sempat ditangani langsung", "fact_class": "SIMULATED"}))
		Narrative.journal(session.world, "tertunda", str(c.get("title", id)),
			str(c.get("story", {}).get("agenda", {}).get("if_postponed",
				"Masalah ini ditangani kementerian teknis tanpa arahan langsung Presiden. Warga di daerah merasakannya.")), id)
		if c.get("story", {}).has("unattended"):
			Narrative.queue(session.world, {"kind": "unattended", "case": id})
		expired.append(id)
	return expired


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
