extends SceneTree
## Headless test runner (no third-party framework).
##   tools/Godot.app/Contents/MacOS/Godot --headless --path game -s res://tests/run_tests.gd
## Exit code 0 = all pass. Each test_* method in the listed suites is executed.

const SUITES := [
	"res://tests/test_simulation.gd",
	"res://tests/test_save.gd",
	"res://tests/test_content.gd",
	"res://tests/test_cases.gd",
	"res://tests/test_case_0001.gd",
	"res://tests/test_budget.gd",
	"res://tests/test_flood_calibration.gd",
	"res://tests/test_policy.gd",
	"res://tests/test_case_template.gd",
	"res://tests/test_case_0002.gd",
	"res://tests/test_case_0003.gd",
	"res://tests/test_case_0004.gd",
	"res://tests/test_case_0005.gd",
	"res://tests/test_case_0006.gd",
	"res://tests/test_case_0007.gd",
	"res://tests/test_case_0008.gd",
	"res://tests/test_map.gd",
	"res://tests/test_regional_sim.gd",
	"res://tests/test_crisis_cases.gd",
]

var failures: PackedStringArray = []
var current := ""
var error_logger := ErrorCounter.new()


## Counts engine/script errors so a test that aborts on a SCRIPT ERROR is reported as FAIL.
class ErrorCounter extends Logger:
	var count := 0
	var last := ""

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		count += 1
		last = rationale if rationale != "" else code


func _initialize() -> void:
	OS.add_logger(error_logger)
	var passed := 0
	var total := 0
	for path in SUITES:
		if not ResourceLoader.exists(path):
			continue
		# A suite that fails to parse must be reported as a failure, never hang the runner (regression 2026-10-06).
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			total += 1
			failures.append("%s: suite failed to load (parse error)" % path.get_file())
			print("  FAIL ", path.get_file(), " (load/parse error)")
			continue
		var suite: Object = script.new()
		suite.set("t", self)
		for m in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			current = path.get_file() + "::" + name
			var before := failures.size()
			var errors_before := error_logger.count
			suite.call(name)
			if error_logger.count > errors_before:
				failures.append("%s: engine/script error: %s" % [current, error_logger.last])
			if failures.size() == before:
				passed += 1
				print("  PASS ", current)
			else:
				print("  FAIL ", current)
	print("\n%d/%d tests passed" % [passed, total])
	for f in failures:
		printerr("  - ", f)
	quit(0 if failures.is_empty() else 1)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func near(a: float, b: float, eps: float, msg: String) -> void:
	check(absf(a - b) <= eps, "%s (got %f, expected %f ± %f)" % [msg, a, b, eps])
