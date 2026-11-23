extends Node
## Autoload: application-level owner of the current Session (authoritative state).
## UI reads from `world` and calls methods here; UI never owns gameplay state.

signal month_advanced(report: Dictionary)
signal world_replaced
signal case_presented(case_id: String)
signal case_resolved(case_id: String, choice_id: String)
signal policy_enacted(policy_id: String)

const DEFAULT_SEED := 20261115

var session: Session
var sim: Simulation:
	get: return session.sim
var world: SimWorld:
	get: return session.world
var cases: CaseEngine:
	get: return session.cases
var saves := SaveService.new()
var autosave_counter := 0
var last_quarter_reports: Array = []  # read-only UI observations; never consulted by the simulation
## "campaign" (main 20-quarter story, saved) or "scenario" (Kumpulan Kisah sandbox, never saved).
var mode := "campaign"
var scenario_case := ""
var _campaign_backup: Session
var _campaign_reports_backup: Array = []


func _ready() -> void:
	# QA/screenshot automation drives the legacy one-case-at-a-time flow; players get the campaign.
	var automation := Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--screenshot=") or a.begins_with("--qa-") or a.begins_with("--map-bench="))
	new_game(DEFAULT_SEED, not automation)


func _make_session(seed_value: int) -> Session:
	return Session.new(ContentDB.sim_params, ContentDB.regions, ContentDB.baseline, ContentDB.cases, seed_value,
		ContentDB.budget, ContentDB.policies)


func new_game(seed_value: int, campaign := true) -> void:
	last_quarter_reports = []
	mode = "campaign"
	scenario_case = ""
	_campaign_backup = null
	session = _make_session(seed_value)
	if campaign:
		Narrative.begin_campaign(session)
	world_replaced.emit()
	present_next_case()


## Campaign: the president takes up one agenda item; its opening scene is queued (Campaign.take).
func take_agenda(case_id: String) -> String:
	var err := Campaign.take(session, case_id)
	if err == "":
		case_presented.emit(case_id)
	return err


func in_scenario() -> bool:
	return mode == "scenario"


## Kumpulan Kisah: plays one top-level case (and its follow-ups) in an isolated sandbox session.
## The campaign session is set aside untouched and restored by end_scenario(); nothing is saved.
func start_scenario(case_id: String) -> String:
	if not ContentDB.cases.has(case_id):
		return "Kisah %s tidak ditemukan." % case_id
	if mode == "campaign":
		_campaign_backup = session
		_campaign_reports_backup = last_quarter_reports
	var family := {}
	for id in ContentDB.cases:
		if id == case_id or str(id).begins_with(case_id + "-"):
			family[id] = ContentDB.cases[id]
	var s := Session.new(ContentDB.sim_params, ContentDB.regions, ContentDB.baseline, family, DEFAULT_SEED,
		ContentDB.budget, ContentDB.policies)
	var st := Narrative.ensure(s.world)
	st["start"] = Narrative.start_values(s)
	st["prologue_done"] = true
	st["tutorial"] = {"step": 0, "done": true}
	st["scenario"] = case_id
	# Fast-forward quietly to the month the story begins (same simulation, no decisions).
	var guard := 0
	while s.present_next_case() == "" and not s.world.is_term_over() and guard < 25:
		s.advance_quarter()
		guard += 1
	if s.pending_case() == "":
		return "Kisah ini tidak dapat dimulai dari awal masa bakti."
	Narrative.queue(s.world, {"kind": "opening", "case": s.pending_case()})
	session = s
	mode = "scenario"
	scenario_case = case_id
	last_quarter_reports = []
	world_replaced.emit()
	return ""


func end_scenario() -> void:
	if mode != "scenario":
		return
	mode = "campaign"
	scenario_case = ""
	if _campaign_backup != null:
		session = _campaign_backup
		last_quarter_reports = _campaign_reports_backup
	else:
		session = _make_session(DEFAULT_SEED)
	_campaign_backup = null
	world_replaced.emit()


func evaluate_ending() -> Dictionary:
	return EndingEvaluator.evaluate(session, ContentDB.story.get("endings", {}))


func present_next_case() -> String:
	var id := session.present_next_case()
	if id != "":
		case_presented.emit(id)
	return id


func pending_case() -> String:
	return session.pending_case()


func decide(case_id: String, choice_id: String) -> String:
	var err := session.decide(case_id, choice_id)
	if err == "":
		case_resolved.emit(case_id, choice_id)
	return err


## Quarterly turn = 3 monthly ticks; autosave at each quarter boundary, then next case.
func advance_quarter() -> Array:
	var reports := session.advance_quarter()
	if reports.is_empty():
		return reports
	last_quarter_reports = reports.duplicate(true)
	for r in reports:
		month_advanced.emit(r)
	if mode == "campaign":
		autosave_counter += 1
		saves.autosave(world.to_dict(), save_meta(), autosave_counter)
	present_next_case()
	return reports


func enact_policy(policy_id: String, target: Dictionary) -> String:
	var err := session.enact_policy(policy_id, target)
	if err == "":
		policy_enacted.emit(policy_id)
	return err


func set_budget(level: float, shares: Dictionary) -> String:
	var err := session.set_budget(level, shares)
	if err == "":
		world_replaced.emit()  # UI refresh; state itself lives in Session.world
	return err


func save_meta() -> Dictionary:
	return {
		"tick": world.tick,
		"year": world.year_index() + 1,
		"quarter": world.quarter_index() % SimWorld.QUARTERS_PER_YEAR + 1,
		"player": "Nara Adinata",
		"snapshot_id": str(ContentDB.baseline.get("snapshot_id", "")),
		"sim_save_schema": SimWorld.SAVE_SCHEMA,
		"national": sim.national_summary(world),
		"chapter": world.quarter_index() + 1,
		"decisions": EndingEvaluator.features(session).decided,
	}


func save_to(slot_id: String, label: String) -> String:
	if mode != "campaign":
		return "Mode Kumpulan Kisah tidak disimpan. Kampanye utamamu tetap aman."
	return saves.save(slot_id, label, world.to_dict(), save_meta())


func load_from(slot_id: String) -> String:
	var r := saves.load_with_recovery(slot_id)
	if not r.ok:
		return r.error
	if mode == "scenario":
		end_scenario()
	var fresh := _make_session(DEFAULT_SEED)
	var err := fresh.world.load_dict(r.payload)
	if err != "":
		return err
	session = fresh
	last_quarter_reports = []
	world_replaced.emit()
	var pend := pending_case()
	if pend != "":
		case_presented.emit(pend)
	return ""
