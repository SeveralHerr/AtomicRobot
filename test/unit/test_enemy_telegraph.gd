extends RefCounted

## Wind-up tell timing and cleanup, and the tuning constants reaching the maids.

var _T

const MAID_SCENE := preload("res://scenes/meter_maid.tscn")
const MELEE_SCENE := preload("res://scenes/meter_maid_melee.tscn")
const MAID_FRAMES := preload("res://sprites/metermaid_sprite_frames.tres")

var _nodes: Array[Node] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _add(scene: PackedScene) -> Enemy:
	var e: Enemy = scene.instantiate()
	_tree().root.add_child(e)
	_nodes.append(e)
	e.set_process(false)
	e.set_physics_process(false)
	return e


func teardown() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			Globals.release_attack_slot(n)
			n.free()
	_nodes.clear()


func test_seconds_to_release_matches_clip_speed() -> String:
	var fps: float = MAID_FRAMES.get_animation_speed("attack")
	var beats := 0.0
	for i in 6:
		beats += MAID_FRAMES.get_frame_duration("attack", i)
	var s := EnemyTelegraph.seconds_to_frame(MAID_FRAMES, "attack", 6, 1.0)
	var r: String = _T.assert_float_eq(s, beats / fps, 0.001, "frames 0-5 (with their durations) at clip fps")
	if r != "":
		return r
	var faster := EnemyTelegraph.seconds_to_frame(MAID_FRAMES, "attack", 6, 2.0)
	r = _T.assert_float_eq(faster, s * 0.5, 0.001, "double speed halves the wind-up")
	if r != "":
		return r
	return _T.assert_float_eq(EnemyTelegraph.seconds_to_frame(MAID_FRAMES, "nope", 6, 1.0), 0.0, 0.0001, "missing clip")


func test_clear_restores_sprite() -> String:
	var e := _add(MAID_SCENE)
	var spr := e.animated_sprite_2d
	var tw := EnemyTelegraph.wind_up(spr, 0.4)
	tw.custom_step(0.4)
	var r: String = _T.assert_gt(EnemyTelegraph.strength(spr), 0.3, "lit by the end of the wind-up")
	if r != "":
		return r
	EnemyTelegraph.clear(spr, tw)
	r = _T.assert_float_eq(EnemyTelegraph.strength(spr), 0.0, 0.0001, "tint off")
	if r != "":
		return r
	return _T.assert_false(tw.is_valid(), "tween killed")


func test_maid_swing_starts_a_tell_and_release_clears_it() -> String:
	var e := _add(MAID_SCENE)
	var st := AttackPlayerState.new(e)
	st._begin_swing()
	var r: String = _T.assert_true(st._tell != null and st._tell.is_valid(), "swing lights the tell")
	if r != "":
		return r
	st._tell.custom_step(1.0)
	r = _T.assert_gt(EnemyTelegraph.strength(e.animated_sprite_2d), 0.0, "glowing mid wind-up")
	if r != "":
		return r
	st._release()
	r = _T.assert_float_eq(EnemyTelegraph.strength(e.animated_sprite_2d), 0.0, 0.0001, "release clears it")
	if r != "":
		return r
	return _T.assert_false(st._tell.is_valid(), "tell tween stopped at release")


func test_boss_swing_has_no_maid_tell() -> String:
	var e := _add(MAID_SCENE)
	var st := BossAttackPlayerState.new(e)
	return _T.assert_false(st.wind_up_tell, "boss keeps his own tells")


func test_tuning_reaches_the_maids() -> String:
	var ranged := _add(MAID_SCENE)
	var melee := _add(MELEE_SCENE)
	var r: String = _T.assert_float_eq(ranged.move_speed, EnemyTuning.RANGED_MOVE_SPEED, 0.001, "ranged speed")
	if r != "":
		return r
	r = _T.assert_float_eq(ranged.attack_timer.wait_time, EnemyTuning.RANGED_ATTACK_COOLDOWN, 0.001, "ranged cooldown")
	if r != "":
		return r
	r = _T.assert_float_eq(melee.move_speed, EnemyTuning.MELEE_MOVE_SPEED, 0.001, "melee speed")
	if r != "":
		return r
	return _T.assert_float_eq(melee.attack_timer.wait_time, EnemyTuning.MELEE_ATTACK_COOLDOWN, 0.001, "melee cooldown")
