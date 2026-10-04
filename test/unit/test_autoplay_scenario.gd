extends RefCounted

## Autoplay scenario parsing/validation (tools/autoplay/scenario.gd). A typo in a
## scenario must fail before any game time is spent, and checks must compare the
## way their text reads.

var _T

const Scenario := preload("res://tools/autoplay/scenario.gd")


func test_defaults_fill_missing_keys() -> String:
	var r: Dictionary = Scenario.parse({})
	var d: Dictionary = r["data"]
	var e: String = _T.assert_true(r["ok"], "empty scenario is valid")
	if e != "":
		return e
	e = _T.assert_eq(d["scene"], "res://scenes/main.tscn", "default scene")
	if e != "":
		return e
	return _T.assert_eq(d["character"], "Ryan", "default character")


func test_every_verb_in_the_table_parses_at_its_min_arity() -> String:
	var samples := {"wait": "1", "hold": "ui_right 1", "tap": "Attack", "press": "Run",
		"release": "Run", "walk_to": "100", "lane": "1", "teleport": "10", "spawn": "melee",
		"god": "on", "hp": "3", "kill_all": "", "sink": "38", "brain": "clear", "menu": "", "snap": "",
		"dump": "", "assert": "kills >= 1"}
	for verb: String in Scenario.VERBS:
		if not samples.has(verb):
			return "no sample for verb '%s' — add one so it stays covered" % verb
		var step: Dictionary = Scenario.parse_step((verb + " " + samples[verb]).strip_edges())
		if step.has("error"):
			return "verb '%s' rejected its own sample: %s" % [verb, step["error"]]
	return ""


func test_unknown_verb_and_bad_arity_are_errors() -> String:
	var r: Dictionary = Scenario.parse({"steps": ["jump_around", "wait", "hold ui_right", "wait 1 2"]})
	var e: String = _T.assert_false(r["ok"], "invalid steps fail the scenario")
	if e != "":
		return e
	return _T.assert_eq(r["errors"].size(), 4, "one error per bad step (too few and too many args)")


## Each of these ran silently before the usability review; all must fail up front.
func test_bad_arguments_are_rejected_before_the_run() -> String:
	for bad in ["spawn boss", "lane 7", "hold attak 1", "wait soon", "hp 2.5", "god yes",
			"brain fly", "walk_to here", "assert kills = 1", "assert kils >= 1",
			"assert kills >= one", "assert scene > main"]:
		if not Scenario.parse_step(bad).has("error"):
			return "'%s' was accepted" % bad
	return ""


func test_valid_arguments_are_accepted() -> String:
	for good in ["spawn ranged -200 3", "lane 0", "hold Attack 0.5", "hp 3", "god off",
			"brain monkey 60", "assert scene == boss_room", "assert x > -100.5"]:
		var s: Dictionary = Scenario.parse_step(good)
		if s.has("error"):
			return "'%s' rejected: %s" % [good, s["error"]]
	return ""


## derive-the-list, both directions: a metric the recorder reports must be
## checkable, and a checkable metric must actually be reported.
func test_metric_list_matches_recorder() -> String:
	var rec: Node = preload("res://tools/autoplay/recorder.gd").new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(rec)
	var keys: Array = rec.metrics(tree).keys()
	rec.free()
	for k in keys:
		if not (k in Scenario.METRICS):
			return "recorder reports '%s' but Scenario.METRICS lacks it" % k
	for k in Scenario.METRICS:
		if not (k in keys):
			return "Scenario.METRICS has '%s' but the recorder never reports it" % k
	return ""


func test_file_source_is_named_after_its_stem() -> String:
	var r: Dictionary = Scenario.load_source(ProjectSettings.globalize_path("res://test/autoplay/smoke_fight.json"))
	return _T.assert_eq(r["data"]["name"], "smoke_fight", "file stem names the report")


func test_name_cannot_escape_the_output_dir() -> String:
	var r: Dictionary = Scenario.load_source('{"name": "../../evil"}')
	return _T.assert_false("/" in r["data"]["name"], "path separators stripped: %s" % r["data"]["name"])


func test_every_shipped_scenario_is_valid() -> String:
	for f in DirAccess.get_files_at("res://test/autoplay"):
		if f.ends_with(".json"):
			var r: Dictionary = Scenario.load_source(ProjectSettings.globalize_path("res://test/autoplay/" + f))
			if not r["ok"]:
				return "%s: %s" % [f, "; ".join(r["errors"])]
	return ""


## A non-number timeout used to raise inside setup() and hang the run.
func test_top_level_values_are_type_checked() -> String:
	for bad in [{"timeout": [5]}, {"timeout": "abc"}, {"timeout": 0}, {"seed": "x"},
			{"scene": "res://scenes/nope.tscn"}, {"character": "Bob"}, {"character": 3}]:
		if Scenario.parse(bad)["ok"]:
			return "%s was accepted" % JSON.stringify(bad)
	return ""


func test_unknown_key_is_an_error() -> String:
	var r: Dictionary = Scenario.parse({"stpes": []})
	return _T.assert_false(r["ok"], "typo'd key 'stpes' is rejected, not ignored")


func test_brain_goal_is_validated() -> String:
	var bad: Dictionary = Scenario.parse_step("brain fly")
	var good: Dictionary = Scenario.parse_step("brain advance 30")
	var e: String = _T.assert_true(bad.has("error"), "unknown goal rejected")
	if e != "":
		return e
	return _T.assert_false(good.has("error"), "advance with seconds accepted")


## `brain advance S X`: fight forward but stop at x=X (route scripting between eggs).
func test_brain_accepts_a_numeric_stop_x() -> String:
	var good: Dictionary = Scenario.parse_step("brain advance 30 400.5")
	var bad: Dictionary = Scenario.parse_step("brain advance 30 far")
	var e: String = _T.assert_false(good.has("error"), "stop x accepted")
	if e != "":
		return e
	e = _T.assert_true(bad.has("error"), "non-numeric stop x rejected")
	if e != "":
		return e
	return _T.assert_eq(good["args"][2], "400.5", "stop x kept as the third arg")


func test_evaluate_compares_numbers_numerically() -> String:
	var m := {"kills": 3, "scene": "main", "t": 2.5}
	var cases := [
		["kills >= 3", true], ["kills > 3", false], ["kills == 3", true], ["kills != 3", false],
		["kills < 10", true], ["kills <= 2", false], ["t > 2", true],
		["scene == main", true], ["scene != boss_room", true],
	]
	for c: Array in cases:
		var r: Dictionary = Scenario.evaluate(Scenario.parse_check(c[0]), m)
		if r["pass"] != c[1]:
			return "'%s' with %s: expected %s, got %s" % [c[0], m, c[1], r["pass"]]
	return ""


func test_unknown_metric_error_names_the_known_ones() -> String:
	var c: Dictionary = Scenario.parse_check("kils >= 1")
	var e: String = _T.assert_true(c.has("error"), "unknown metric rejected at parse time")
	if e != "":
		return e
	return _T.assert_true("kills" in c["error"], "error lists the real metric names")


func test_malformed_check_is_an_error() -> String:
	return _T.assert_true(Scenario.parse_check("kills=1").has("error"), "check needs spaces around op")


func test_inline_json_source_parses() -> String:
	var r: Dictionary = Scenario.load_source('{"steps": ["wait 1"]}')
	var e: String = _T.assert_true(r["ok"], "inline JSON accepted")
	if e != "":
		return e
	return _T.assert_eq(r["data"]["name"], "inline", "inline scenarios are named 'inline'")


func test_missing_file_is_an_error() -> String:
	var r: Dictionary = Scenario.load_source("res://does/not/exist.json")
	return _T.assert_false(r["ok"], "missing file reported")


## The mortal 100% route is the god-mode route without `god on`: a step added to one
## (e.g. the sidewalk step before the last news stand) must reach the other.
func test_mortal_completionist_route_matches_the_god_route() -> String:
	var god: Dictionary = Scenario.load_source("res://test/autoplay/completionist_run.json")["data"]
	var mortal: Dictionary = Scenario.load_source("res://test/autoplay/completionist_mortal.json")["data"]
	var want: Array = god["steps"].map(func(s: Dictionary) -> String: return s["text"]).filter(
			func(t: String) -> bool: return t != "god on")
	var got: Array = mortal["steps"].map(func(s: Dictionary) -> String: return s["text"])
	return _T.assert_eq(got, want, "mortal steps == god steps minus 'god on'")
