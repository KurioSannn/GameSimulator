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


func _ready() -> void:
	new_game(DEFAULT_SEED)


func _make_session(seed_value: int) -> Session:
	return Session.new(ContentDB.sim_params, ContentDB.regions, ContentDB.baseline, ContentDB.cases, seed_value,
		ContentDB.budget, ContentDB.policies)


func new_game(seed_value: int) -> void:
	session = _make_session(seed_value)
	world_replaced.emit()
	present_next_case()


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
	for r in reports:
		month_advanced.emit(r)
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
	}


func save_to(slot_id: String, label: String) -> String:
	return saves.save(slot_id, label, world.to_dict(), save_meta())


func load_from(slot_id: String) -> String:
	var r := saves.load_with_recovery(slot_id)
	if not r.ok:
		return r.error
	var fresh := _make_session(DEFAULT_SEED)
	var err := fresh.world.load_dict(r.payload)
	if err != "":
		return err
	session = fresh
	world_replaced.emit()
	var pend := pending_case()
	if pend != "":
		case_presented.emit(pend)
	return ""
