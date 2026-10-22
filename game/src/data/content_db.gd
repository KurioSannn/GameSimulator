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
var load_errors: PackedStringArray = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	load_errors = []
	var reg := _read_json(REGIONS_PATH)
	regions = reg.get("regions", [])
	provinces = reg.get("provinces", [])
	source_institutions = reg.get("source_institutions", {})
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
