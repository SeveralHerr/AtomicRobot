extends RefCounted

# The death beat (scripts/ui/death_beat.gd, owned by the EndCard): on Globals.player_death
# the game drops to slow-mo for a moment of real time, the level greys out, and only
# then does the GAME OVER card appear. The signal itself is NOT delayed - score, door
# encounters, the boss room and enemies still react on the killing blow.

var _T

const BOSS_ROOM := "res://scenes/boss_room.tscn"
const MAIN := "res://scenes/main.tscn"

var _level: Node


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func _card(path: String = BOSS_ROOM) -> EndCard:
	_level = (load(path) as PackedScene).instantiate()
	_tree().root.add_child(_level)
	await _frames()
	return _level.get_node("UI/EndCard") as EndCard


func _panel(card: EndCard) -> Control:
	return card.find_child("Card", true, false) as Control


func _grey(card: EndCard) -> float:
	return float(card.dim_material.get_shader_parameter("grey"))


func _until_card(card: EndCard, limit: float = 4.0) -> void:
	var end := Time.get_ticks_msec() + int(limit * 1000)
	while is_instance_valid(card) and not _panel(card).is_visible_in_tree() and Time.get_ticks_msec() < end:
		await _tree().process_frame


func teardown() -> void:
	_tree().paused = false
	if is_instance_valid(_level):
		_level.queue_free()
	_level = null
	await _frames()
	Engine.time_scale = 1.0


func test_death_drops_to_slow_mo_before_the_card() -> String:
	var card := await _card()
	Globals.player_death.emit()
	await _frames()
	var r: String = _T.assert_float_eq(Engine.time_scale, DeathBeat.SLOW_SCALE, 0.001, "slow-mo on the killing blow")
	if r != "":
		return r
	r = _T.assert_false(_panel(card).is_visible_in_tree(), "card waits for the beat")
	if r != "":
		return r
	return _T.assert_false(card.restart_button.is_visible_in_tree(), "no RESTART to mash during the beat")


func test_street_death_has_the_beat_too() -> String:
	var card := await _card(MAIN)
	Globals.player_death.emit()
	await _frames()
	var r: String = _T.assert_float_eq(Engine.time_scale, DeathBeat.SLOW_SCALE, 0.001, "street slow-mo")
	if r != "":
		return r
	return _T.assert_false(_panel(card).is_visible_in_tree(), "street card waits")


func test_card_follows_slow_mo_then_grey() -> String:
	var card := await _card()
	var start := Time.get_ticks_msec()
	Globals.player_death.emit()
	await _until_card(card)
	var waited := (Time.get_ticks_msec() - start) / 1000.0
	var r: String = _T.assert_true(_panel(card).is_visible_in_tree(), "card shows after the beat")
	if r != "":
		return r
	r = _T.assert_gte(waited, DeathBeat.SLOW_SECONDS + DeathBeat.GREY_SECONDS - 0.05, "card held for the whole beat")
	if r != "":
		return r
	r = _T.assert_float_eq(Engine.time_scale, 1.0, 0.001, "time back to normal under the card")
	if r != "":
		return r
	return _T.assert_float_eq(_grey(card), 1.0, 0.001, "level fully grey under the card")


func test_level_greys_out_between_slow_mo_and_card() -> String:
	var card := await _card()
	Globals.player_death.emit()
	await _tree().create_timer(DeathBeat.SLOW_SECONDS * 0.5, true, false, true).timeout
	var r: String = _T.assert_float_eq(_grey(card), 0.0, 0.001, "still in colour during slow-mo")
	if r != "":
		return r
	await _tree().create_timer(DeathBeat.SLOW_SECONDS * 0.5 + DeathBeat.GREY_SECONDS * 0.5, true, false, true).timeout
	var g := _grey(card)
	if g <= 0.05 or g >= 0.95:
		return "grey should be mid-tween after slow-mo, got %.2f" % g
	r = _T.assert_float_eq(Engine.time_scale, 1.0, 0.001, "slow-mo over once the grey starts")
	if r != "":
		return r
	return _T.assert_false(_panel(card).is_visible_in_tree(), "card waits for the grey")


func test_leaving_mid_beat_restores_time() -> String:
	await _card(MAIN)  # not the boss room: its own _exit_tree resets time too
	Globals.player_death.emit()
	await _frames()
	_level.queue_free()
	_level = null
	await _frames()
	return _T.assert_float_eq(Engine.time_scale, 1.0, 0.001, "time restored when the level goes")


func test_pause_mid_beat_runs_at_normal_speed() -> String:
	await _card()
	Globals.player_death.emit()
	await _frames()
	_tree().paused = true
	await _frames()
	var r: String = _T.assert_float_eq(Engine.time_scale, 1.0, 0.001, "pause menu runs at full speed")
	if r != "":
		return r
	_tree().paused = false
	await _frames()
	return _T.assert_float_eq(Engine.time_scale, DeathBeat.SLOW_SCALE, 0.001, "slow-mo resumes on unpause")


## A hit-stop ending (or the boss's ticketed slow-mo) writes 1.0 mid-beat; the beat
## must win it back on the next frame.
func test_beat_holds_slow_mo_against_a_reset() -> String:
	await _card()
	Globals.player_death.emit()
	await _frames()
	Engine.time_scale = 1.0
	await _frames()
	return _T.assert_float_eq(Engine.time_scale, DeathBeat.SLOW_SCALE, 0.001, "beat keeps its slow-mo")


func test_second_death_signal_does_not_restart_the_beat() -> String:
	var card := await _card()
	var start := Time.get_ticks_msec()
	Globals.player_death.emit()
	await _tree().create_timer(0.3, true, false, true).timeout
	Globals.player_death.emit()
	await _until_card(card)
	var waited := (Time.get_ticks_msec() - start) / 1000.0
	var r: String = _T.assert_true(waited < DeathBeat.SLOW_SECONDS + DeathBeat.GREY_SECONDS + 0.25,
		"a second signal must not restart the beat (card after %.2fs)" % waited)
	if r != "":
		return r
	# A restarted beat would still be greying the level in under the card.
	await _tree().create_timer(0.15, true, false, true).timeout
	return _T.assert_float_eq(_grey(card), 1.0, 0.001, "one grey-out, finished under the card")


func test_win_has_no_death_beat() -> String:
	var card := await _card()
	Globals.boss_death.emit()
	await _frames()
	var r: String = _T.assert_float_eq(Engine.time_scale, 1.0, 0.001, "no slow-mo on a win (the finale had it)")
	if r != "":
		return r
	r = _T.assert_true(_panel(card).is_visible_in_tree(), "YOU WIN shows at once")
	if r != "":
		return r
	return _T.assert_float_eq(_grey(card), 0.0, 0.001, "a win stays in colour")


## Pausing and unpausing during ordinary play must never switch slow-mo on.
func test_pause_without_a_death_keeps_normal_time() -> String:
	await _card()
	_tree().paused = true
	await _frames()
	_tree().paused = false
	await _frames()
	return _T.assert_float_eq(Engine.time_scale, 1.0, 0.001, "no slow-mo without a death")


## Dying in the same moment the boss falls: the win card stays a win.
func test_win_during_the_beat_is_not_overwritten() -> String:
	var card := await _card()
	Globals.player_death.emit()
	await _frames()
	Globals.boss_death.emit()
	while card.beat.running:
		await _tree().process_frame
	await _frames()
	return _T.assert_eq(card._title.text, "YOU WIN!", "late GAME OVER must not replace YOU WIN")


## Someone else's slow-mo (the boss finale) is not the beat's to cancel on a pause.
func test_pause_leaves_other_slow_mo_alone() -> String:
	await _card()
	Engine.time_scale = 0.2
	_tree().paused = true
	await _frames()
	var scale := Engine.time_scale
	_tree().paused = false
	return _T.assert_float_eq(scale, 0.2, 0.001, "pause outside a beat leaves time_scale alone")
