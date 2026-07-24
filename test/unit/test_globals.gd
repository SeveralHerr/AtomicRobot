extends RefCounted

# Headless sanity tests for the Globals autoload's data (character roster and
# destroyed-node tracking). Instantiates the script directly — no scene tree needed.

var _T
var _globals


func setup() -> void:
	_globals = load("res://scripts/autoload/globals.gd").new()


func teardown() -> void:
	if _globals:
		_globals.free()
		_globals = null


func test_character_dict_has_expected_roster() -> String:
	var expected := ["Cody", "Ryan", "Sara", "Cass", "Caitlyn", "Robot"]
	for name in expected:
		if not _globals.character_dict.has(name):
			return "character_dict missing '%s'" % name
	return _T.assert_eq(_globals.character_dict.size(), expected.size(), "roster size")


func test_every_character_config_is_playable() -> String:
	for name in _globals.character_dict:
		var cfg = _globals.character_dict[name]
		if cfg == null:
			return "%s: null config" % name
		if cfg.get_sprite_frames() == null:
			return "%s: null sprite_frames" % name
		if cfg.get_starting_health() <= 0:
			return "%s: starting_health %d <= 0" % [name, cfg.get_starting_health()]
		if cfg.get_starting_damage() <= 0:
			return "%s: starting_damage %d <= 0" % [name, cfg.get_starting_damage()]
		if cfg.get_attack_frame() < 0:
			return "%s: negative attack_frame" % name
	return ""


func test_default_selected_character_exists() -> String:
	return _T.assert_true(
		_globals.character_dict.has(_globals.selected_character),
		"selected_character '%s' must be in character_dict" % _globals.selected_character
	)


func test_destroyed_node_tracking() -> String:
	var r: String = _T.assert_false(_globals.is_node_destroyed("Crate1"), "fresh node not destroyed")
	if r != "":
		return r
	_globals.mark_node_destroyed("Crate1")
	return _T.assert_true(_globals.is_node_destroyed("Crate1"), "marked node reports destroyed")


func test_reset_clears_session_state() -> String:
	_globals.meter_maids_killed = 5
	_globals.reset()
	return _T.assert_eq(_globals.meter_maids_killed, 0, "kill count after reset")
