extends RefCounted

# The live ScoreSystem autoload: per-stage best, the high-score list, and what it
# hands the end card (last_run, awaiting_initials). Each test points the autoload at a
# throwaway save file so the player's real user://scores.cfg is never touched.

var _T

const STAGE := "res://scenes/boss_room.tscn"
const SANDBOX := "res://test/scenes/melee_cluster.tscn"
const TEST_SAVE := "user://test_scores.cfg"

var _saved_path: String


func setup() -> void:
	_saved_path = ScoreSystem.save_path
	ScoreSystem.save_path = TEST_SAVE
	ScoreSystem.clear_records()


func teardown() -> void:
	ScoreSystem.clear_records()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	ScoreSystem.save_path = _saved_path
	ScoreSystem.reload()
	ScoreSystem.begin_stage("")
	ScoreSystem.running = false


func _play(points: int, scene: String = STAGE) -> void:
	ScoreSystem.current_scene_path = scene
	ScoreSystem.begin_stage(scene)
	ScoreSystem.score = points


# --- Characterisation: per-stage best ----------------------------------------

func test_finish_records_a_new_best() -> String:
	_play(5000)
	var result: Dictionary = ScoreSystem.finish_stage()
	var r: String = _T.assert_true(bool(result["is_new_best"]), "first clear is a best")
	if r != "":
		return r
	return _T.assert_eq(ScoreSystem.best_for(STAGE), int(result["total"]), "best saved")


func test_finish_twice_only_scores_once() -> String:
	_play(100)
	ScoreSystem.finish_stage()
	return _T.assert_eq(ScoreSystem.finish_stage().size(), 0, "second finish is a no-op")


func test_lower_run_keeps_old_best() -> String:
	_play(9000)
	var first: int = int(ScoreSystem.finish_stage()["total"])
	_play(10)
	var second: Dictionary = ScoreSystem.finish_stage()
	var r: String = _T.assert_false(bool(second["is_new_best"]), "worse run is not a best")
	if r != "":
		return r
	return _T.assert_eq(ScoreSystem.best_for(STAGE), first, "best unchanged")


func test_best_survives_reload() -> String:
	_play(4321)
	var total: int = int(ScoreSystem.finish_stage()["total"])
	ScoreSystem.reload()
	return _T.assert_eq(ScoreSystem.best_for(STAGE), total, "best read back from disk")


# --- High-score list ---------------------------------------------------------

func test_clear_records_last_run_and_offers_initials() -> String:
	_play(5000)
	var result: Dictionary = ScoreSystem.finish_stage()
	var run: Dictionary = ScoreSystem.last_run
	var r: String = _T.assert_true(bool(run["won"]), "a clear is a win")
	if r != "":
		return r
	r = _T.assert_eq(int(run["total"]), int(result["total"]), "last_run carries the total")
	if r != "":
		return r
	r = _T.assert_eq(int(run["slot"]), 0, "first run on an empty list is 1st")
	if r != "":
		return r
	r = _T.assert_true(ScoreSystem.awaiting_initials, "initials wanted")
	if r != "":
		return r
	var slot: int = ScoreSystem.submit_initials("jdh")
	r = _T.assert_eq(slot, 0, "lands first")
	if r != "":
		return r
	r = _T.assert_false(ScoreSystem.awaiting_initials, "submit ends the wait")
	if r != "":
		return r
	ScoreSystem.reload()
	var row: Dictionary = ScoreSystem.high_scores[0]
	r = _T.assert_eq(String(row["initials"]), "JDH", "initials saved upper-case")
	if r != "":
		return r
	return _T.assert_eq(String(row["rank"]), String(result["rank"]), "rank saved")


## Like pinball: the next entry starts on the last initials used, across restarts.
func test_last_initials_persist() -> String:
	var r: String = _T.assert_eq(ScoreSystem.last_initials, HighScoreTable.DEFAULT_INITIALS, "fresh save starts AAA")
	if r != "":
		return r
	_play(500)
	Globals.player_death.emit()
	ScoreSystem.submit_initials("KAT")
	ScoreSystem.reload()
	return _T.assert_eq(ScoreSystem.last_initials, "KAT", "last initials read back")


func test_death_with_score_offers_initials_without_rank() -> String:
	_play(700)
	Globals.player_death.emit()
	var r: String = _T.assert_true(ScoreSystem.awaiting_initials, "a dying high scorer gets initials")
	if r != "":
		return r
	r = _T.assert_false(bool(ScoreSystem.last_run["won"]), "a death is not a win")
	if r != "":
		return r
	r = _T.assert_eq(int(ScoreSystem.last_run["total"]), 700, "death total is the fight score")
	if r != "":
		return r
	ScoreSystem.submit_initials("DIE")
	r = _T.assert_eq(int(ScoreSystem.high_scores[0]["score"]), 700, "fight score kept")
	if r != "":
		return r
	return _T.assert_eq(String(ScoreSystem.high_scores[0]["rank"]), "", "no rank card, no letter")


func test_zero_score_death_does_not_offer() -> String:
	_play(0)
	Globals.player_death.emit()
	var r: String = _T.assert_false(ScoreSystem.awaiting_initials, "nothing to record")
	if r != "":
		return r
	return _T.assert_eq(int(ScoreSystem.last_run["slot"]), -1, "not placed")


## Sandboxes under test/scenes/ score (for combo asserts) but must never write to
## the player's high-score list.
func test_sandbox_never_offers() -> String:
	_play(5000, SANDBOX)
	ScoreSystem.finish_stage()
	var r: String = _T.assert_false(ScoreSystem.awaiting_initials, "sandbox clear")
	if r != "":
		return r
	return _T.assert_eq(ScoreSystem.high_scores.size(), 0, "list untouched")


func test_non_qualifier_does_not_wait() -> String:
	for i in HighScoreTable.SIZE:
		HighScoreTable.insert(ScoreSystem.high_scores, HighScoreTable.make_entry("TOP", 1_000_000))
	_play(10)
	Globals.player_death.emit()
	return _T.assert_false(ScoreSystem.awaiting_initials, "full board of better runs")


## A double submit (two fingers, or A mashed) must not write the run twice.
func test_submit_twice_writes_once() -> String:
	_play(500)
	Globals.player_death.emit()
	ScoreSystem.submit_initials("ONE")
	var r: String = _T.assert_eq(ScoreSystem.submit_initials("TWO"), -1, "second submit refused")
	if r != "":
		return r
	return _T.assert_eq(ScoreSystem.high_scores.size(), 1, "one row")


func test_restart_mid_entry_cancels_the_wait() -> String:
	_play(500)
	Globals.player_death.emit()
	ScoreSystem.begin_stage(STAGE)
	var r: String = _T.assert_false(ScoreSystem.awaiting_initials, "a fresh stage drops the stale offer")
	if r != "":
		return r
	return _T.assert_eq(ScoreSystem.last_run.size(), 0, "and the stale result")


# --- The run: street score carries through the boss door ---------------------

const STREET := "res://scenes/main.tscn"


## Street -> (the swap's empty frame) -> boss room, alive: one run.
func _walk_through_door(street_points: int) -> void:
	ScoreSystem.enter_scene(STREET)
	ScoreSystem.score = street_points
	ScoreSystem.stage_seconds = 100.0
	ScoreSystem.damage_taken = 2
	ScoreSystem.enter_scene("", false)
	ScoreSystem.enter_scene(STAGE)


func test_run_street_score_carries_into_boss() -> String:
	_walk_through_door(7000)
	var r: String = _T.assert_eq(ScoreSystem.score, 7000, "street score kept")
	if r != "":
		return r
	r = _T.assert_eq(ScoreSystem.stage_seconds, 100.0, "run clock kept")
	if r != "":
		return r
	r = _T.assert_eq(ScoreSystem.damage_taken, 2, "damage kept")
	if r != "":
		return r
	ScoreSystem.score += 600
	var res: Dictionary = ScoreSystem.finish_stage()
	r = _T.assert_eq(int(res["street_score"]), 7000, "street subtotal")
	if r != "":
		return r
	return _T.assert_eq(int(res["boss_score"]), 600, "boss subtotal")


func test_run_death_on_street_starts_fresh() -> String:
	ScoreSystem.enter_scene(STREET)
	ScoreSystem.score = 7000
	Globals.player_death.emit()
	ScoreSystem.enter_scene("", false)
	ScoreSystem.enter_scene(STAGE)
	return _T.assert_eq(ScoreSystem.score, 0, "a dead run does not carry")


func test_run_menu_between_drops_the_carry() -> String:
	ScoreSystem.enter_scene(STREET)
	ScoreSystem.score = 7000
	ScoreSystem.enter_scene("res://scenes/startscreen.tscn")
	ScoreSystem.enter_scene(STAGE)
	return _T.assert_eq(ScoreSystem.score, 0, "quitting to the title ends the run")


func test_run_boss_only_stage_is_fresh() -> String:
	ScoreSystem.enter_scene(STAGE)
	var r: String = _T.assert_eq(ScoreSystem.street_score, 0, "no street part")
	if r != "":
		return r
	return _T.assert_eq(ScoreSystem.score, 0, "starts at zero")


func test_run_death_in_boss_room_records_run_total() -> String:
	_walk_through_door(7000)
	ScoreSystem.score += 300
	Globals.player_death.emit()
	return _T.assert_eq(int(ScoreSystem.last_run["total"]), 7300, "list entry is the whole run")


func test_run_secrets_counted_once_and_paid() -> String:
	ScoreSystem.enter_scene(STREET)
	Globals.secret_found.emit("wall", "A")
	Globals.secret_found.emit("wall", "A")
	Globals.secret_found.emit("news", "B")
	ScoreSystem.enter_scene("", false)
	ScoreSystem.enter_scene(STAGE)
	var res: Dictionary = ScoreSystem.finish_stage()
	var r: String = _T.assert_eq(res["secrets"], {"wall": 1, "news": 1}, "unique per run")
	if r != "":
		return r
	r = _T.assert_eq(int(res["secret_bonus"]), ScoreRules.secret_bonus(2), "paid per secret")
	if r != "":
		return r
	return _T.assert_eq(res["secret_totals"], SecretTally.totals_in(ScoreRules.SCORED_SCENES), "totals from the level")


func test_run_secrets_reset_on_a_new_run() -> String:
	ScoreSystem.enter_scene(STREET)
	Globals.secret_found.emit("news", "B")
	ScoreSystem.enter_scene("res://scenes/character_select.tscn")
	ScoreSystem.enter_scene(STREET)
	return _T.assert_eq(ScoreSystem.secrets.found_total(), 0, "fresh run, no secrets")


func test_run_secret_after_the_run_ended_is_ignored() -> String:
	ScoreSystem.enter_scene(STAGE)
	Globals.player_death.emit()
	Globals.secret_found.emit("news", "B")
	return _T.assert_eq(ScoreSystem.secrets.found_total(), 0, "not running, not counted")


func test_run_unlock_is_reported() -> String:
	# tools/run_tests.gd points Globals at a scratch unlock save with Robot locked.
	ScoreSystem.enter_scene(STAGE)
	Globals.boss_death.emit()
	var unlocks: Array = ScoreSystem.last_run.get("unlocks", [])
	ScoreSystem.enter_scene(STAGE)
	Globals.boss_death.emit()
	var again: Array = ScoreSystem.last_run.get("unlocks", [])
	var r: String = _T.assert_eq(unlocks, ["Robot"], "first clear unlocks Robot")
	if r != "":
		return r
	return _T.assert_eq(again, [], "already unlocked: nothing new")


## Mutation survivor: a run that ends with a fighter still locked reports no unlock.
func test_run_still_locked_is_not_an_unlock() -> String:
	# tools/run_tests.gd points Globals at a scratch unlock save with Robot locked.
	ScoreSystem.enter_scene(STAGE)
	ScoreSystem.finish_stage()  # cleared without the boss_death unlock
	var unlocks: Array = ScoreSystem.last_run.get("unlocks", [])
	return _T.assert_eq(unlocks, [], "Robot still locked")
