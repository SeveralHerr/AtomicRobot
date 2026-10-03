extends RefCounted

# Robot ships locked, is earned by beating the boss (once, saved to disk), and is
# deliberately overpowered. run_tests.gd points Globals at a scratch save and restores
# shipped lock states before every test, so these drive the real autoload.

var _T

const Unlocks := preload("res://scripts/character_unlocks.gd")
const SAVE := "user://test_unlocks.cfg"

var _announced: Array = []
var _fresh: Node


func setup() -> void:
	_announced.clear()
	Globals.unlocked.connect(_on_unlocked)


func teardown() -> void:
	Globals.unlocked.disconnect(_on_unlocked)
	if is_instance_valid(_fresh):
		_fresh.free()


func _on_unlocked(header: String, description: String) -> void:
	_announced.append([header, description])


func _robot() -> CharacterConfig:
	return Globals.character_dict["Robot"]


## A Globals as a fresh boot would build it, reading the test save.
func _reboot() -> Node:
	_fresh = load("res://scripts/autoload/globals.gd").new()
	_fresh.unlocks_path = SAVE
	_fresh.load_unlocks()
	return _fresh


# --- Shipped state -------------------------------------------------------------

func test_robot_ships_locked() -> String:
	var g: Node = load("res://scripts/autoload/globals.gd").new()
	var locked: bool = not g.character_dict["Robot"].unlocked
	g.free()
	return _T.assert_true(locked, "Robot starts locked")


func test_everyone_else_ships_unlocked() -> String:
	for c in Globals.character_dict:
		if c != "Robot" and not Globals.character_dict[c].unlocked:
			return "%s should ship unlocked" % c
	return ""


func test_locked_robot_tells_you_how_to_unlock() -> String:
	return _T.assert_true("BOSS" in _robot().get_unlock_hint().to_upper(), "hint names the boss: %s" % _robot().get_unlock_hint())


# --- Overpowered ---------------------------------------------------------------

func test_robot_doubles_every_other_fighter() -> String:
	for c in Globals.character_dict:
		if c == "Robot":
			continue
		var o: CharacterConfig = Globals.character_dict[c]
		var r: String = _T.assert_gte(_robot().get_starting_health(), 2 * o.get_starting_health(), "Robot HP vs %s" % c)
		if r != "":
			return r
		r = _T.assert_gte(_robot().get_starting_damage(), 2 * o.get_starting_damage(), "Robot damage vs %s" % c)
		if r != "":
			return r
	return ""


func test_robot_health_fits_the_hud() -> String:
	return _T.assert_true(_robot().get_starting_health() <= Player.MAX_ORBS,
		"%d orbs must fit the %d-orb HUD" % [_robot().get_starting_health(), Player.MAX_ORBS])


# --- Earning it ----------------------------------------------------------------

func test_boss_death_unlocks_robot() -> String:
	Globals.boss_death.emit()
	return _T.assert_true(_robot().unlocked, "beating the boss unlocks Robot")


func test_boss_death_announces_once() -> String:
	for i in 3:  # the boss re-emits on every hit after 0 HP
		Globals.boss_death.emit()
	var r: String = _T.assert_eq(_announced.size(), 1, "one ROBOT IS NOW PLAYABLE, not three")
	if r != "":
		return r
	r = _T.assert_eq(_announced[0][0], "ROBOT IS NOW PLAYABLE", "notification header")
	if r != "":
		return r
	return _T.assert_eq(Array(Globals.unseen_unlocks), ["Robot"], "queued once for the select reveal")


func test_unlock_survives_a_restart() -> String:
	Globals.boss_death.emit()
	return _T.assert_true(_reboot().character_dict["Robot"].unlocked, "a fresh boot reads Robot from the save")


func test_no_save_means_shipped_state() -> String:
	return _T.assert_false(_reboot().character_dict["Robot"].unlocked, "no save, Robot stays locked")


func test_garbage_save_is_ignored() -> String:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{{ not a config file")
	f.close()
	return _T.assert_false(_reboot().character_dict["Robot"].unlocked, "corrupt save doesn't unlock or crash")


func test_unknown_fighter_in_save_is_ignored() -> String:
	Unlocks.save_unlocked(SAVE, "Nobody")
	var g := _reboot()
	return _T.assert_false(g.character_dict.has("Nobody"), "a stray key doesn't invent a fighter")


func test_save_keeps_earlier_unlocks() -> String:
	Unlocks.save_unlocked(SAVE, "Cody")
	Unlocks.save_unlocked(SAVE, "Robot")
	var got := Array(Unlocks.load_unlocked(SAVE))
	got.sort()
	return _T.assert_eq(got, ["Cody", "Robot"], "second unlock doesn't overwrite the first")


func test_already_unlocked_is_not_reannounced_after_restart() -> String:
	Unlocks.save_unlocked(SAVE, "Robot")
	Globals.load_unlocks()
	Globals.boss_death.emit()
	return _T.assert_eq(_announced.size(), 0, "beating the boss again doesn't re-announce Robot")
