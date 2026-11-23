extends Node
## Autoload: loads game-ready content exports once at startup (read-only during play).
## Never parses research/raw data and never touches the network.

const REGIONS_PATH := "res://data/regions.json"
const BASELINE_PATH := "res://data/baseline.json"
const PARAMS_PATH := "res://data/sim_params.json"
const BUDGET_PATH := "res://data/budget.json"
const CASES_DIR := "res://data/cases"
const POLICIES_DIR := "res://data/policies"
const POLICY_CATEGORIES_PATH := "res://data/policy_categories.json"

var regions: Array = []          # kab/kota simulation entities, in simulation index order
var provinces: Array = []
var province_by_id: Dictionary = {}
var region_by_id: Dictionary = {}
var baseline: Dictionary = {}
var sim_params: Dictionary = {}
var budget: Dictionary = {}      # DERIVED budget config (sectors, base shares, pool status)
var cases: Dictionary = {}       # case_id -> case record
var policies: Dictionary = {}    # policy_id -> policy record
var policy_categories: Array = []
var source_institutions: Dictionary = {}   # source_id -> institution (for REAL fact labels)
var sources: Dictionary = {}  # offline provenance, exported from the existing research registry
var load_errors: PackedStringArray = []
## Story content (game/data/story): cast, prologue, tutorial, quarter transitions, endings.
var story: Dictionary = {}
const STORY_DIR := "res://data/story"


func _ready() -> void:
	load_all()


func load_all() -> void:
	load_errors = []
	var reg := _read_json(REGIONS_PATH)
	regions = reg.get("regions", [])
	provinces = reg.get("provinces", [])
	source_institutions = reg.get("source_institutions", {})
	sources = _read_json("res://data/ui/sources.json").get("sources", {})
	region_by_id.clear()
	province_by_id.clear()
	for r in regions:
		region_by_id[r["region_id"]] = r
	for p in provinces:
		province_by_id[p["region_id"]] = p
	baseline = _read_json(BASELINE_PATH)
	sim_params = _read_json(PARAMS_PATH)
	budget = _read_json(BUDGET_PATH)
	cases = {}
	for path in _list_json(CASES_DIR):
		var c := _read_json(path)
		if c.has("case_id"):
			cases[c["case_id"]] = c
	policies = {}
	for path in _list_json(POLICIES_DIR):
		var pr := _read_json(path)
		if pr.has("policy_id"):
			policies[pr["policy_id"]] = pr
	policy_categories = _read_json(POLICY_CATEGORIES_PATH).get("categories", [])
	story = {}
	for key in ["cast", "prologue", "tutorial", "quarters", "endings", "credits"]:
		story[key] = _read_json("%s/%s.json" % [STORY_DIR, key])
	merge_episodes(cases, STORY_DIR + "/episodes")
	var order: Array = baseline.get("region_order", [])
	if order.size() != regions.size():
		load_errors.append("baseline.region_order tidak cocok dengan regions.json")
	if not load_errors.is_empty():
		push_error("ContentDB: " + ", ".join(load_errors))


## Per-region provenance of a variable's starting value: REAL | PROVINCE_PROXY | UNCALIBRATED.
func region_baseline_status(var_name: String, region_index: int) -> String:
	var spec: Dictionary = baseline.get("variables", {}).get(var_name, {})
	var rs: Variant = spec.get("region_status")
	if rs is Array and region_index < (rs as Array).size():
		return str(rs[region_index])
	match str(spec.get("status", "")):
		"UNCALIBRATED": return "UNCALIBRATED"
		"BY_DESIGN": return "BY_DESIGN"  # model state, not a measurement (reason in provenance.reason)
	return "REAL"


## Simulation variables whose starting values are still neutral defaults (no data ingested yet).
func uncalibrated_variables() -> Array:
	var out: Array = []
	var vars: Dictionary = baseline.get("variables", {})
	for v in vars:
		if str(vars[v].get("status", "")) == "UNCALIBRATED":
			out.append(v)
	return out


func baseline_status(var_name: String) -> String:
	return str(baseline.get("variables", {}).get(var_name, {}).get("status", "UNKNOWN"))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		load_errors.append("berkas tidak ditemukan: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		load_errors.append("JSON tidak valid: " + path)
		return {}
	return parsed


func _list_json(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(dir_path.path_join(f))
	out.sort()
	return out


## Character record from the story cast, or a neutral narrator/local fallback.
func character(id: String, case_record: Dictionary = {}) -> Dictionary:
	var cast: Dictionary = story.get("cast", {}).get("characters", {})
	if cast.has(id):
		return cast[id]
	var locals: Dictionary = case_record.get("story", {}).get("locals", {})
	if locals.has(id):
		var c: Dictionary = locals[id].duplicate()
		if str(c.get("portrait", "")) == "":
			var path := local_portrait_path(str(case_record.get("case_id", "")), id)
			if ResourceLoader.exists(path):
				c["portrait"] = path
				c["portrait_kind"] = "card"
		return c
	return {"name": "", "role": "", "color": "8a7a5a"}


## Portrait of an episode's local character. Follow-ups (CASE-0001-A) share the parent case's cast.
static func local_portrait_path(case_id: String, local_id: String) -> String:
	return "res://assets/story/portraits/locals/%s_%s.jpg" % [case_id.substr(0, 9), local_id]


## Top-level playable cases (major historical) in id order: the Kumpulan Kisah library.
func library_cases() -> Array:
	var ids: Array = cases.keys().filter(func(id): return str(cases[id].get("class", "")) == "major_historical")
	ids.sort()
	return ids


## Merges narrative episodes (game/data/story/episodes/<case_id>.json, FICTIONAL) into case records as
## case["story"]. Kept separate from the researched case data so provenance and fiction never mix.
static func merge_episodes(case_records: Dictionary, dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var ep: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + f))
		if ep is Dictionary and case_records.has(str(ep.get("case_id", ""))):
			case_records[str(ep.case_id)]["story"] = ep
