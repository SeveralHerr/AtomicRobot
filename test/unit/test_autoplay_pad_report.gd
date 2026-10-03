extends RefCounted

## Autoplay virtual controller + report (tools/autoplay/pad.gd, report.gd).

var _T

const Pad := preload("res://tools/autoplay/pad.gd")
const Report := preload("res://tools/autoplay/report.gd")


func test_pad_events_are_real_key_events_for_every_bot_action() -> String:
	# Menus read AnyButton.is_press, which ignores InputEventAction: the bot must
	# send the same key events a keyboard would.
	for action in [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_accept", &"Attack", &"Run", &"Crouch"]:
		var e := Pad.event_for(action, true)
		if not (e is InputEventKey):
			return "%s has no key binding; the bot would send a %s" % [action, e.get_class()]
		if not e.is_action_pressed(action):
			return "event for %s does not trigger it" % action
	return ""


func test_pad_release_event_is_a_release() -> String:
	var e := Pad.event_for(&"Attack", false)
	return _T.assert_false(e.is_pressed(), "release event is not pressed")


func test_pad_tap_cooldown_lets_the_key_come_up() -> String:
	var pad := Pad.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(pad)
	pad.set_physics_process(false)
	pad.tap(&"ui_up")
	for f in Pad.TAP_FRAMES:
		pad._physics_process(0.0)
	pad.tap(&"ui_up")  # same frame as the auto-release: must be refused
	var held := pad.is_held(&"ui_up")
	pad.release_all()
	pad.free()
	return _T.assert_false(held, "re-tap on the release frame is refused (edge detectors need a gap)")


## Second lock on shipping the bot (the first is OS.has_feature("template") in
## scripts/autoload/autoplay.gd): every export preset must exclude it.
func test_every_export_preset_excludes_the_bot_and_tests() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") != OK:
		return "export_presets.cfg did not load"
	var presets := 0
	for section in cfg.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		presets += 1
		var f: String = cfg.get_value(section, "exclude_filter", "")
		for needle in ["tools/autoplay/*", "test/*"]:
			if not (needle in f):
				return "%s (%s) exclude_filter lacks %s" % [section, cfg.get_value(section, "name"), needle]
	return _T.assert_gt(presets, 0, "found export presets")


func test_sanitize_replaces_inf_and_nan_nested() -> String:
	var v: Variant = Report.sanitize({"a": INF, "b": [NAN, 1.0], "c": {"d": -INF}})
	var json := JSON.stringify(v)
	var e: String = _T.assert_true(JSON.parse_string(json) != null, "sanitized report is valid JSON")
	if e != "":
		return e
	return _T.assert_eq(v["b"][1], 1.0, "finite values kept")


func test_summary_is_short_and_ends_with_result() -> String:
	var m := {"t": 1.0, "frames": 60, "scene": "main", "x": 0, "lane": 1, "hp": 3, "max_hp": 30,
		"state": "IdleState", "kills": 0, "hits_taken": 0, "damage_taken": 0, "heals": 0,
		"deaths": 0, "won": 0, "score": 0, "max_stuck_s": 0.0, "errors": 0, "engine_errors": 0, "warnings": 0}
	var r := {"name": "x", "result": "PASS", "reason": "", "metrics": m, "scenes": ["main"],
		"stuck_spots": [], "errors": [], "asserts": [{"pass": true, "text": "kills >= 0", "actual": 0}], "snaps": []}
	var lines := Report.summary(r, "out/x.json").split("\n")
	var e: String = _T.assert_true(lines.size() <= 15, "summary fits a glance (%d lines)" % lines.size())
	if e != "":
		return e
	return _T.assert_eq(lines[-1], "RESULT: PASS", "last line is the machine-readable result")
