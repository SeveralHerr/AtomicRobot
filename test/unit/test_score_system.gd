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
