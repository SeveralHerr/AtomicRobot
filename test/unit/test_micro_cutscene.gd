extends RefCounted

## The street cut scenes in the real level: the opening plays on load only when a run
## started from the front end, freezes the fight (player, enemies, buffs), hides the
## HUD, skips on a button, and always hands the camera and controls back.

var _T

const MAIN := "res://scenes/main.tscn"

var _level: Node
var _old_scene: Node


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func _load(enabled: bool) -> Player:
	StreetCutscenes.enabled = enabled
	StreetCutscenes.seen = {}
	_level = (load(MAIN) as PackedScene).instantiate()
	_tree().root.add_child(_level)
	await _frames(3)
	return _level.get_node("Player") as Player


func _until(cond: Callable, seconds: float = 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func _scene() -> MicroCutscene:
	return _level.find_child("MicroCutscene_opening", true, false) as MicroCutscene


func _until_settled() -> bool:
	return await _until(func(): return _scene() != null and _scene().is_settled(), MicroCutscene.SETTLE_MAX + 0.5)


func _hud_alpha() -> float:
	var nodes := _tree().get_nodes_in_group(HudFade.CINEMATIC)
	return (nodes[0] as CanvasItem).modulate.a if not nodes.is_empty() else -1.0


func _hold(seconds: float) -> void:
	Input.action_press(&"ui_accept")
	await _until(func(): return false, seconds)
	Input.action_release(&"ui_accept")


func teardown() -> void:
	Input.action_release(&"ui_accept")
	if _old_scene != null:
		_tree().current_scene = _old_scene
		_old_scene = null
	StreetCutscenes.enabled = false
	StreetCutscenes.seen = {}
	if is_instance_valid(_level):
		_level.queue_free()
	_level = null
	await _frames()
	MicroCutscene.playing = false
	HudFade.release(_tree(), HudFade.CINEMATIC)


## Player report: story scenes "skipped for no reason" — every run after the first in
## a session started with them all marked seen. Each load of the level (a new run or a
## RESTART after a death) plays them again.
func test_every_level_load_replays_the_story() -> String:
	StreetCutscenes.enabled = false
	StreetCutscenes.seen = {"opening": true, "arch": true, "council": true}
	_level = (load(MAIN) as PackedScene).instantiate()
	_tree().root.add_child(_level)
	await _frames(2)
	return _T.assert_true(StreetCutscenes.seen.is_empty(), "seen cleared on load: %s" % [StreetCutscenes.seen])


func test_directly_loaded_level_plays_no_cutscene() -> String:
	var p := await _load(false)
	var r: String = _T.assert_false(MicroCutscene.playing, "tests and autoplay load main.tscn straight")
	if r != "":
		return r
	return _T.assert_true(p.is_physics_processing(), "player live from frame one")


func test_opening_freezes_the_fight_and_takes_the_camera() -> String:
	var p := await _load(true)
	var r: String = _T.assert_true(MicroCutscene.playing, "opening plays on load")
	if r == "":
		r = _T.assert_true(await _until_settled(), "every body held within SETTLE_MAX")
	if r == "":
		r = _T.assert_false(p.is_physics_processing(), "player frozen")
	if r == "":
		r = _T.assert_true(p.god_mode, "player can't be hurt mid-scene")
	if r == "":
		r = _T.assert_false(p.camera_2d.is_current(), "cut-scene camera has the view")
	if r == "":
		r = _T.assert_float_eq(_hud_alpha(), 0.0, 0.001, "HUD gone on the first frame")
	if r == "":
		for e in _tree().get_nodes_in_group("enemies"):
			if e.can_process():
				return "enemy %s still processing during the scene" % e.name
	return r


## The real way in: the level loads under Transition's fade with the tree paused,
## so the opening's first frame (no HUD, bars in) must be set without tweens.
func test_opening_is_framed_while_the_fade_reveals_it() -> String:
	StreetCutscenes.enabled = true
	StreetCutscenes.seen = {}
	Transition.fade_through(func() -> Error:
		_level = (load(MAIN) as PackedScene).instantiate()
		_tree().root.add_child(_level)
		return OK)
	await _until(func(): return MicroCutscene.playing, 2.0)
	var scene: MicroCutscene = _level.find_child("MicroCutscene_opening", true, false)
	var r: String = _T.assert_true(_tree().paused, "still inside the fade")
	if r == "":
		r = _T.assert_float_eq(_hud_alpha(), 0.0, 0.001, "HUD hidden before the reveal")
	if r == "":
		r = _T.assert_float_eq(scene._bars[0].position.y, 0.0, 0.001, "top bar already in")
	await _until(func(): return not Transition.busy, 2.0)
	return r


## The opening starts the frame the level loads, with the player and the roof maid
## still at their spawn heights: each is held only once it has landed.
func test_opening_holds_bodies_on_the_ground_not_in_the_air() -> String:
	# Through the real fade, like the game: the tree is paused while the level loads,
	# and main.tscn is the current scene (lanes only exist there).
	StreetCutscenes.enabled = true
	StreetCutscenes.seen = {}
	_old_scene = _tree().current_scene
	Transition.fade_through(func() -> Error:
		_level = (load(MAIN) as PackedScene).instantiate()
		_tree().root.add_child(_level)
		_tree().current_scene = _level
		return OK)
	await _until(func(): return MicroCutscene.playing, 2.0)
	await _until_settled()
	var p := _tree().get_first_node_in_group("player") as Player
	var r: String = _T.assert_true(p.is_settled(), "player standing on its spawn lane, not floating at spawn height")
	if r != "":
		return r
	for e in _tree().get_nodes_in_group("enemies"):
		if e is MeterMaidWindow or e.can_process():
			continue  # window maids hang in their frames; live ones aren't held
		if absf(e.global_position.x - p.global_position.x) < 900.0 and not e.is_on_floor():
			return "%s held in mid-air at %s" % [e.name, e.global_position]
	return ""


## The frame a fresh player touches the walkway it is grounded but not yet snapped
## to its road lane: holding it there showed a 48px drop at hand-back.
## Everything walking in the opening's first shot (the maids by the red car) must
## start where it stands: authored in mid-air, they visibly dropped onto the street.
func test_nothing_in_the_first_shot_falls() -> String:
	StreetCutscenes.enabled = true
	StreetCutscenes.seen = {}
	_old_scene = _tree().current_scene
	var start := {}
	Transition.fade_through(func() -> Error:
		_level = (load(MAIN) as PackedScene).instantiate()
		_tree().root.add_child(_level)
		_tree().current_scene = _level
		return OK)
	var first: Dictionary = CutsceneShots.scene("opening")["shots"][0]
	var half := CutsceneShots.half_view(first["zoom"])
	await _until(func(): return MicroCutscene.playing, 2.0)
	for e in _tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.lane_locked and absf(e.global_position.x - first["at"].x) < half.x:
			start[e] = e.global_position.y
	var r: String = _T.assert_gt(start.size(), 0, "the first shot has walkers in it")
	if r != "":
		return r
	await _until_settled()
	for e in start:
		if absf(e.global_position.y - start[e]) > 2.0:
			return "%s dropped %.0fpx in the opening shot" % [e.name, e.global_position.y - start[e]]
		if e.can_process():
			return "%s never held" % e.name
	return ""


## Enemies rarely read is_on_floor() after a step, so "landed" for them is: the street
## baseline is captured and they are not falling.
func test_enemy_counts_as_landed_once_it_has_a_baseline_and_no_fall() -> String:
	var c := MicroCutscene.new()
	var maid: Enemy = preload("res://scenes/meter_maid_melee.tscn").instantiate()
	maid.lane_floor_y = INF
	maid.velocity = Vector2.ZERO
	var r: String = _T.assert_false(c._landed(maid), "no baseline yet: still spawning in")
	maid.lane_floor_y = -1.0
	maid.velocity.y = 120.0
	if r == "":
		r = _T.assert_false(c._landed(maid), "falling")
	maid.velocity.y = 0.0
	if r == "":
		r = _T.assert_true(c._landed(maid), "on the street")
	maid.free()
	c.free()
	return r


func test_player_is_not_settled_on_the_walkway_before_its_lane_snap() -> String:
	# Lanes only exist when main.tscn is the current scene; build it fresh as that.
	StreetCutscenes.enabled = false
	_old_scene = _tree().current_scene
	_level = (load(MAIN) as PackedScene).instantiate()
	_tree().root.add_child(_level)
	_tree().current_scene = _level
	await _tree().process_frame
	var p := _tree().get_first_node_in_group("player") as Player
	var seen_landing := false
	for i in 120:
		await _tree().physics_frame
		if p.is_grounded() and not p._spawn_lane_applied:
			seen_landing = true
			if p.is_settled():
				return "settled on the walkway, one frame before the lane snap"
		if p._spawn_lane_applied:
			break
	var r: String = _T.assert_true(p.is_settled(), "settled once on its spawn lane")
	if r == "" and not seen_landing:
		r = "never caught the walkway landing frame (test no longer exercises the guard)"
	return r


func test_skip_hands_everything_back() -> String:
	var p := await _load(true)
	await _frames(2)
	await _hold(MicroCutscene.SKIP_HOLD + 0.1)
	var ok: bool = await _until(func(): return not MicroCutscene.playing, 1.5)
	var r: String = _T.assert_true(ok, "skip ends the scene fast")
	if r == "":
		r = _T.assert_true(p.camera_2d.is_current(), "play camera back")
	if r == "":
		r = _T.assert_true(p.is_physics_processing(), "player live again")
	if r == "":
		r = _T.assert_false(p.god_mode, "god mode restored to what it was")
	if r == "":
		for e in _tree().get_nodes_in_group("enemies"):
			if not e.can_process():
				return "enemy %s left frozen" % e.name
	return r


## Mashing through the front end must not eat the story: a tap only shows the prompt.
func test_a_tap_shows_the_prompt_but_does_not_skip() -> String:
	await _load(true)
	await _frames(2)
	await _hold(0.2)
	var prompt: SkipPrompt = _scene().find_child("SkipPrompt", true, false)
	var r: String = _T.assert_gt(prompt.modulate.a, 0.0, "HOLD TO SKIP appears on a press")
	if r != "":
		return r
	await _until(func(): return false, MicroCutscene.SKIP_HOLD + 0.2)
	return _T.assert_true(MicroCutscene.playing, "a tap is not a skip")


func test_short_holds_do_not_add_up_to_a_skip() -> String:
	await _load(true)
	await _frames(2)
	for i in 2:
		await _hold(MicroCutscene.SKIP_HOLD * 0.6)
		await _frames(3)
	await _until(func(): return false, MicroCutscene.SKIP_RETURN_TIME + 0.2)
	return _T.assert_true(MicroCutscene.playing, "letting go drains the ring")


func test_a_button_already_down_at_the_start_does_not_skip() -> String:
	Input.action_press(&"ui_accept")
	await _load(true)
	await _until(func(): return false, MicroCutscene.SKIP_HOLD + 0.4)
	return _T.assert_true(MicroCutscene.playing, "the press that left the splash, still held, is not a skip")


func test_pause_is_not_a_skip_button() -> String:
	return _T.assert_false(&"pause" in MicroCutscene.SKIP_ACTIONS, "pause pauses the scene instead")


func test_opening_runs_to_the_end_on_its_own() -> String:
	var p := await _load(true)
	var limit := CutsceneShots.duration("opening") + MicroCutscene.RETURN_TIME + 1.0
	var ok: bool = await _until(func(): return not MicroCutscene.playing, limit)
	var r: String = _T.assert_true(ok, "opening ended within %.1fs" % limit)
	if r == "":
		r = _T.assert_true(p.camera_2d.is_current(), "play camera back")
	if r == "":
		r = _T.assert_true(await _until(func(): return _hud_alpha() > 0.99, 1.5), "HUD faded back")
	return r


## The user's call (2026-10-04): a RESTART after a death replays the story too.
func test_opening_replays_on_restart() -> String:
	await _load(true)
	var r: String = _T.assert_true(StreetCutscenes.seen.has("opening"), "marked seen")
	if r != "":
		return r
	_level.queue_free()
	await _frames()
	MicroCutscene.playing = false
	_level = (load(MAIN) as PackedScene).instantiate()
	_tree().root.add_child(_level)
	await _frames(3)
	return _T.assert_true(MicroCutscene.playing, "a restart replays it")


func test_leaving_mid_scene_clears_the_flag_and_buff_hold() -> String:
	await _load(true)
	_level.queue_free()
	_level = null
	await _frames()
	var r: String = _T.assert_false(MicroCutscene.playing, "no stale playing flag")
	if r != "":
		return r
	return _T.assert_false(PowerupSystem.is_held(), "buff timers not left on hold")
