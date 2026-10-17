extends RefCounted

# Robot ships locked, is earned once every other fighter has beaten the boss (each
# win saved to disk), and is deliberately overpowered. run_tests.gd points Globals at a scratch save and restores
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


## Every fighter but `last` has already won; `last` is up for the final clear.
func _one_win_away(last := "Cody") -> void:
	for c in Globals.robot_contenders():
		if c != last:
			Globals.record_win(c)
	Globals.selected_character = last


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
	var h := _robot().get_unlock_hint().to_upper()
	return _T.assert_true("BOSS" in h and "EVERY FIGHTER" in h, "hint names the boss and every fighter: %s" % h)


# --- Overpowered ---------------------------------------------------------------

func test_robot_out_hits_and_out_lasts_every_other_fighter() -> String:
	for c in Globals.character_dict:
		if c == "Robot":
			continue
		var o: CharacterConfig = Globals.character_dict[c]
		var r: String = _T.assert_gte(_robot().get_starting_health(), 2 * o.get_starting_health(), "Robot HP vs %s" % c)
		if r != "":
			return r
		# Damage on the DamageRules scale: "doubles" became "fewest blows per maid" —
		# 2x of a 3-4 damage fighter would one-shot (test_damage_scale forbids that).
		var robot_hits := DamageRules.hits_to_kill(DamageRules.MAID_HEALTH, _robot().get_starting_damage())
		var their_hits := DamageRules.hits_to_kill(DamageRules.MAID_HEALTH, o.get_starting_damage())
		r = _T.assert_gt(their_hits, robot_hits, "Robot blows per maid vs %s" % c)
		if r != "":
			return r
	return ""


func test_robot_health_fits_the_hud() -> String:
	return _T.assert_true(_robot().get_starting_health() <= Player.MAX_ORBS,
		"%d orbs must fit the %d-orb HUD" % [_robot().get_starting_health(), Player.MAX_ORBS])


# --- Earning it ----------------------------------------------------------------

func test_one_fighter_beating_the_boss_does_not_unlock_robot() -> String:
	Globals.selected_character = "Ryan"
	Globals.boss_death.emit()
	var r: String = _T.assert_false(_robot().unlocked, "one clear isn't enough")
	if r != "":
		return r
	return _T.assert_eq(Globals.robot_progress(), Vector2i(1, 6), "Ryan's win counts")


func test_every_fighter_beating_the_boss_unlocks_robot() -> String:
	for c in Globals.robot_contenders():
		var r: String = _T.assert_false(_robot().unlocked, "still locked before %s wins" % c)
		if r != "":
			return r
		Globals.selected_character = c
		Globals.boss_death.emit()
	return _T.assert_true(_robot().unlocked, "the last fighter's clear unlocks Robot")


func test_repeat_wins_by_one_fighter_count_once() -> String:
	Globals.selected_character = "Sara"
	for i in 6:
		Globals.boss_death.emit()
	var r: String = _T.assert_false(_robot().unlocked, "six Sara clears aren't six fighters")
	if r != "":
		return r
	return _T.assert_eq(Globals.robot_progress(), Vector2i(1, 6), "Sara counted once")


func test_robot_is_not_a_contender() -> String:
	return _T.assert_false("Robot" in Globals.robot_contenders(), "Robot can't earn itself")


func test_wins_survive_a_restart() -> String:
	Globals.selected_character = "Cass"
	Globals.boss_death.emit()
	return _T.assert_eq(Array(_reboot().beaten), ["Cass"], "a fresh boot reads Cass's win from the save")


func test_switching_save_forgets_wins() -> String:
	Globals.record_win("Cass")
	Globals.use_unlock_save(SAVE + ".other")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + ".other"))
	var r: String = _T.assert_eq(Globals.robot_progress().x, 0, "another save starts with no wins")
	Globals.use_unlock_save(SAVE)
	return r


func test_boss_death_unlocks_robot() -> String:
	_one_win_away()
	Globals.boss_death.emit()
	return _T.assert_true(_robot().unlocked, "the final fighter's clear unlocks Robot")


func test_boss_death_announces_once() -> String:
	_one_win_away()
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
	_one_win_away()
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
	_one_win_away()
	Globals.boss_death.emit()
	return _T.assert_eq(_announced.size(), 0, "beating the boss again doesn't re-announce Robot")


func test_use_unlock_save_restores_shipped_then_applies() -> String:
	Globals.character_dict["Robot"].unlocked = true
	Globals.use_unlock_save(SAVE)  # empty scratch save
	var r: String = _T.assert_false(_robot().unlocked, "back to shipped: Robot locked")
	if r != "":
		return r
	Unlocks.save_unlocked(SAVE, "Robot")
	Globals.use_unlock_save(SAVE)
	return _T.assert_true(_robot().unlocked, "then that save's unlocks apply")


func test_tests_never_touch_the_real_save() -> String:
	return _T.assert_eq(Globals.unlocks_path, SAVE, "runner points Globals at the scratch save")


func test_only_bool_true_unlocks() -> String:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string('[unlocked]\nRobot="yes"\nCody=1\nSara=true\n')
	f.close()
	return _T.assert_eq(Array(Unlocks.load_unlocked(SAVE)), ["Sara"], "strings/ints don't count as unlocked")


func test_end_card_restart_keeps_the_reveal() -> String:
	# End card RESTART runs Globals.reset() before opening character select.
	_one_win_away()
	Globals.boss_death.emit()
	Globals.reset()
	var r: String = _T.assert_true(_robot().unlocked, "reset doesn't re-lock Robot")
	if r != "":
		return r
	return _T.assert_eq(Array(Globals.unseen_unlocks), ["Robot"], "reveal still queued for select")
