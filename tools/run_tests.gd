extends SceneTree

## Headless unit test runner.
##   godot --headless --path . --script res://tools/run_tests.gd [-- --filter NAME]
## Exit: 0 all passed, 1 a test failed, 2 a test script failed to load/compile.
##
## Contract: test/unit/**/test_*.gd extend RefCounted, optional setup()/teardown(),
## each test_* method returns "" on pass or a failure message. The runner is injected
## as `_T` for the assert_* helpers. Any method may await.
##
## GDScript has no exceptions: a runtime error inside a test aborts it and returns
## "" (a pass). _ErrorCounter catches those script errors so the test fails instead.

const TEST_DIR := "res://test/unit"

class _ErrorCounter extends Logger:
	var count := 0
	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, error_type: int,
			_script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			count += 1

var _errors := _ErrorCounter.new()
var _passed := 0
var _failed := 0
var _broken := 0


func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	var i := args.find("--filter")
	if i != -1 and i + 1 < args.size():
		filter = args[i + 1]

	OS.add_logger(_errors)
	# Let root finish entering the tree so tests that add_child() get a viewport.
	await process_frame
	_isolate_unlocks()
	for path in _find_tests(TEST_DIR):
		await _run_script(path, filter)

	print("\nTotal: %d | Passed: %d | Failed: %d | Broken scripts: %d"
		% [_passed + _failed, _passed, _failed, _broken])
	quit(2 if _broken else (1 if _failed else 0))


func _find_tests(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for sub in DirAccess.get_directories_at(dir_path):
		out += _find_tests(dir_path.path_join(sub))
	for f in DirAccess.get_files_at(dir_path):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	out.sort()
	return out


func _run_script(path: String, filter: String) -> void:
	var script := load(path) as GDScript
	# A script with a parse error still loads; new() on it would abort the whole run.
	if script == null or not script.can_instantiate():
		printerr("BROKEN  %s (failed to load/compile, see stderr)" % path)
		_broken += 1
		return
	var obj: RefCounted = script.new()
	obj.set("_T", get_script())
	for m in script.get_script_method_list():
		var name: String = m["name"]
		if name.begins_with("test_") and (filter == "" or name.contains(filter)):
			await _run_test(obj, name, path)


func _run_test(obj: RefCounted, name: String, path: String) -> void:
	# Start every test from an idle frame: a previous test that ended on
	# `await physics_frame` would otherwise leave this one running inside the
	# physics step, where get_process_frames() hasn't ticked yet.
	await process_frame
	_reset_unlocks()
	if obj.has_method("setup"):
		await obj.call("setup")
	var errors_before := _errors.count
	var result: Variant = await obj.call(name)
	var msg := "" if result == null else str(result)
	if msg == "" and _errors.count > errors_before:
		msg = "script error during test (see SCRIPT ERROR above)"
	if msg == "":
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL  %s::%s  %s" % [path.get_file(), name, msg])
	if obj.has_method("teardown"):
		await obj.call("teardown")


## Fighter unlocks persist to user://. A test must never read the player's real save
## (a player who beat the boss would see Robot-locked tests fail) nor write it (any
## test that emits Globals.boss_death would unlock Robot for real). Point Globals at
## a scratch file and restore the shipped lock states before every test.
const TEST_UNLOCKS := "user://test_unlocks.cfg"
var _shipped_unlocks := {}


func _isolate_unlocks() -> void:
	var fresh: Node = load("res://scripts/autoload/globals.gd").new()
	for c in fresh.character_dict:
		_shipped_unlocks[c] = fresh.character_dict[c].unlocked
	fresh.free()
	root.get_node("Globals").unlocks_path = TEST_UNLOCKS


func _reset_unlocks() -> void:
	var g: Node = root.get_node("Globals")
	for c in _shipped_unlocks:
		g.character_dict[c].unlocked = _shipped_unlocks[c]
	g.unseen_unlocks = PackedStringArray()
	DirAccess.remove_absolute(TEST_UNLOCKS)


static func assert_eq(actual: Variant, expected: Variant, context: String = "") -> String:
	return "" if actual == expected else "%s: expected %s, got %s" % [context, expected, actual]

static func assert_true(condition: bool, context: String = "") -> String:
	return "" if condition else "%s: expected true" % context

static func assert_false(condition: bool, context: String = "") -> String:
	return "" if not condition else "%s: expected false" % context

static func assert_float_eq(actual: float, expected: float, tolerance: float = 0.001, context: String = "") -> String:
	return "" if absf(actual - expected) <= tolerance else "%s: expected %s ±%s, got %s" % [context, expected, tolerance, actual]

static func assert_gt(actual: Variant, threshold: Variant, context: String = "") -> String:
	return "" if actual > threshold else "%s: expected > %s, got %s" % [context, threshold, actual]

static func assert_gte(actual: Variant, threshold: Variant, context: String = "") -> String:
	return "" if actual >= threshold else "%s: expected >= %s, got %s" % [context, threshold, actual]
