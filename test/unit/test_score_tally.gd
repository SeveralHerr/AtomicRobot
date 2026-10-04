extends RefCounted

# End card reveal beat (scripts/ui/score_tally.gd + RunSummary): FINAL SCORE rolls up
# with rising coin ticks, the rank stamp slams on the last tick, then hint and badge.

var _T

const BOSS_ROOM := "res://scenes/boss_room.tscn"
const TEST_SAVE := "user://test_scores_tally.cfg"

var _level: Node
var _saved_path: String


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func setup() -> void:
	_saved_path = ScoreSystem.save_path
	ScoreSystem.save_path = TEST_SAVE
	ScoreSystem.clear_records()


func teardown() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
	ScoreSystem.begin_stage("")
	ScoreSystem.running = false
	ScoreSystem.clear_records()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	ScoreSystem.save_path = _saved_path
	ScoreSystem.reload()
	await _frames()


func test_tally_value_runs_from_zero_to_total_without_going_back() -> String:
	var r: String = _T.assert_eq(ScoreTally.value_at(0.0, 12345), 0, "starts at 0")
	if r != "":
		return r
	r = _T.assert_eq(ScoreTally.value_at(1.0, 12345), 12345, "lands on the total")
	if r != "":
		return r
	var last := -1
	for i in 21:
		var v := ScoreTally.value_at(i / 20.0, 12345)
		if v < last:
			return "value fell at step %d: %d < %d" % [i, v, last]
		last = v
	return _T.assert_gt(ScoreTally.value_at(0.5, 12345), int(12345 * 0.8), "races early, settles late")


func test_tally_ticks_climb_in_pitch() -> String:
	var r: String = _T.assert_float_eq(ScoreTally.tick_pitch(0), ScoreTally.PITCH_FROM, 0.001, "first tick")
	if r != "":
		return r
	r = _T.assert_float_eq(ScoreTally.tick_pitch(ScoreTally.TICKS - 1), ScoreTally.PITCH_TO, 0.001, "last tick")
	if r != "":
		return r
	for i in range(1, ScoreTally.TICKS):
		if ScoreTally.tick_pitch(i) <= ScoreTally.tick_pitch(i - 1):
			return "tick %d does not climb" % i
	return ""


func _win() -> EndCard:
	_level = (load(BOSS_ROOM) as PackedScene).instantiate()
	_tree().root.add_child(_level)
	await _frames()
	ScoreSystem.enter_scene(BOSS_ROOM)
	ScoreSystem.score = 9000
	var card := _level.get_node("UI/EndCard") as EndCard
	Globals.boss_death.emit()
	await _frames()
	return card


func test_card_score_rolls_then_stamp_slams_and_hint_follows() -> String:
	var card := await _win()
	var final_text := ComicStyle.format_score(int(ScoreSystem.last_run["total"]))
	var s := card.summary
	var r: String = _T.assert_true(s.score_label.text != final_text, "still rolling right after the card opens")
	if r != "":
		return r
	r = _T.assert_float_eq(s.stamp.modulate.a, 0.0, 0.001, "stamp waits for the tally")
	if r != "":
		return r
	var stamps := [0]
	s.stamped.connect(func() -> void: stamps[0] += 1)
	await _tree().create_timer(RunSummary.TALLY_DELAY + ScoreTally.SECONDS + RunSummary.SLAM_SECONDS + 0.4).timeout
	r = _T.assert_eq(s.score_label.text, final_text, "lands on the total")
	if r != "":
		return r
	r = _T.assert_eq(stamps[0], 1, "stamp slammed once, on the last tick")
	if r != "":
		return r
	r = _T.assert_float_eq(s.stamp.modulate.a, 1.0, 0.001, "stamp shown")
	if r != "":
		return r
	return _T.assert_float_eq(s.ladder.modulate.a, 1.0, 0.001, "hint revealed")


func test_card_repaint_shows_the_settled_card_at_once() -> String:
	var card := await _win()
	card.present(true)  # a second signal: repaint, not a second beat
	await _frames()
	var s := card.summary
	var r: String = _T.assert_eq(s.score_label.text, ComicStyle.format_score(int(ScoreSystem.last_run["total"])), "final number")
	if r != "":
		return r
	r = _T.assert_float_eq(s.ladder.modulate.a, 1.0, 0.001, "hint shown")
	if r != "":
		return r
	return _T.assert_float_eq(s.stamp.modulate.a, 1.0, 0.001, "stamp shown")
