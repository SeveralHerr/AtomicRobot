extends RefCounted

# Characterization of Enemy's lane movement: stepping between lanes (tween, cooldown,
# ground-collision toggling), chasing the player's lane, standing on a road lane's
# virtual floor, and same-lane separation. Pins behaviour before it moved out of
# enemy.gd into collaborators.

var _T

const MAID_SCENE := preload("res://scenes/meter_maid.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STREET := -28.0

var _nodes: Array[Node] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _maid(x: float = 0.0, lane: int = Lanes.GROUND_LANE) -> Enemy:
	var e: Enemy = MAID_SCENE.instantiate()
	e.lane_floor_y = STREET
	_tree().root.add_child(e)
	_nodes.append(e)
	e.set_process(false)
	e.set_physics_process(false)
	e.attack_timer.stop()
	e.lane = lane
	if lane != Lanes.GROUND_LANE:
		e.set_collision_mask_value(2, false)  # as a road-lane body really stands
		e.set_collision_mask_value(6, false)
	e.global_position = Vector2(x, e.lane_stand_y(lane))
	return e


func _player(lane: int) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	_tree().root.add_child(p)
	_nodes.append(p)
	p.set_process(false)
	p.set_physics_process(false)
	p.current_lane = lane
	return p


func teardown() -> void:
	await _tree().process_frame
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _ground_mask_on(e: Enemy) -> bool:
	return e.get_collision_mask_value(2) and e.get_collision_mask_value(6)


func _finish_tween() -> void:
	await _tree().create_timer(Enemy.LANE_CHANGE_DURATION + 0.15).timeout


func test_lane_change_starts_a_step_and_drops_ground_collision() -> String:
	var e := _maid()
	e._start_lane_change(2)
	var r: String = _T.assert_true(e.is_changing_lane, "stepping")
	if r != "":
		return r
	r = _T.assert_float_eq(e.lane_change_cooldown, Enemy.LANE_CHANGE_COOLDOWN, 0.0001, "cooldown armed")
	if r != "":
		return r
	r = _T.assert_eq(e.lane, Lanes.GROUND_LANE, "lane only commits when the step lands")
	if r != "":
		return r
	return _T.assert_false(_ground_mask_on(e), "road-bound step ignores walkway collision")


func test_lane_change_lands_on_target_floor() -> String:
	var e := _maid()
	e._start_lane_change(2)
	await _finish_tween()
	var r: String = _T.assert_eq(e.lane, 2, "landed on lane 2")
	if r != "":
		return r
	r = _T.assert_false(e.is_changing_lane, "step finished")
	if r != "":
		return r
	return _T.assert_float_eq(e.global_position.y, e.lane_stand_y(2), 0.5, "stands on lane 2's floor")


func test_lane_change_back_to_walkway_restores_ground_collision() -> String:
	var e := _maid(0.0, 1)
	e._start_lane_change(Lanes.GROUND_LANE)
	var r: String = _T.assert_false(_ground_mask_on(e), "collision stays off mid-step")
	if r != "":
		return r
	await _finish_tween()
	r = _T.assert_eq(e.lane, Lanes.GROUND_LANE, "back on the walkway")
	if r != "":
		return r
	return _T.assert_true(_ground_mask_on(e), "walkway collision back on")


func test_lane_change_is_a_noop_without_baseline_or_to_same_lane() -> String:
	var e := _maid()
	e._start_lane_change(Lanes.GROUND_LANE)
	var r: String = _T.assert_false(e.is_changing_lane, "same lane is a no-op")
	if r != "":
		return r
	e.lane_floor_y = INF
	e._start_lane_change(2)
	return _T.assert_false(e.is_changing_lane, "no baseline, no step")


func test_lane_change_clamps_target() -> String:
	var e := _maid()
	e._start_lane_change(99)
	await _finish_tween()
	return _T.assert_eq(e.lane, Lanes.FRONT_LANE, "target clamped to the front lane")


func test_lane_chase_steps_one_lane_toward_player() -> String:
	var e := _maid()
	e.player = _player(3)
	e._lane_chase()
	var r: String = _T.assert_true(e.is_changing_lane, "chasing steps")
	if r != "":
		return r
	await _finish_tween()
	return _T.assert_eq(e.lane, 1, "one lane at a time")


func test_lane_chase_guards() -> String:
	var e := _maid()
	e.player = _player(3)
	e.lane_locked = true
	e._lane_chase()
	var r: String = _T.assert_false(e.is_changing_lane, "lane-locked never chases")
	if r != "":
		return r
	e.lane_locked = false
	e.lane_change_cooldown = 0.1
	e._lane_chase()
	r = _T.assert_false(e.is_changing_lane, "cooldown blocks")
	if r != "":
		return r
	e.lane_change_cooldown = 0.0
	e.player.is_changing_lane = true
	e._lane_chase()
	r = _T.assert_false(e.is_changing_lane, "waits while the player is mid-step")
	if r != "":
		return r
	e.player.is_changing_lane = false
	e.player.current_lane = Lanes.GROUND_LANE
	e._lane_chase()
	return _T.assert_false(e.is_changing_lane, "same lane: nothing to chase")


func test_gravity_snaps_onto_road_lane_floor() -> String:
	var e := _maid(0.0, 2)
	e.global_position.y = e.lane_stand_y(2) + 5.0
	e.velocity.y = 40.0
	e._apply_gravity(0.1)
	var r: String = _T.assert_float_eq(e.global_position.y, e.lane_stand_y(2), 0.001, "snapped to floor")
	if r != "":
		return r
	return _T.assert_float_eq(e.velocity.y, 0.0, 0.001, "fall stopped")


func test_gravity_pulls_while_airborne_and_rising() -> String:
	var e := _maid(0.0, 2)
	e.global_position.y = e.lane_stand_y(2) + 5.0
	e.velocity.y = -40.0
	e._apply_gravity(0.1)
	return _T.assert_float_eq(e.velocity.y, -10.0, 0.001, "300 px/s^2 while rising off a road floor")


func test_gravity_paused_while_changing_lane() -> String:
	var e := _maid(0.0, 2)
	e.is_changing_lane = true
	e.velocity.y = 7.0
	e._apply_gravity(0.1)
	return _T.assert_float_eq(e.velocity.y, 7.0, 0.001, "the tween owns Y mid-step")


func test_separation_pushes_overlapping_same_lane_maids_apart() -> String:
	var a := _maid(0.0, 1)
	var b := _maid(10.0, 1)
	EnemySeparation.apply(a, 0.1)
	# push = (40 - 10) / 40 = 0.75; 0.75 * 160 * 0.1 = 12 px away from b.
	var r: String = _T.assert_float_eq(a.global_position.x, -12.0, 0.001, "a pushed left, away from b")
	if r != "":
		return r
	EnemySeparation.apply(b, 0.1)
	return _T.assert_gt(b.global_position.x, 10.0, "b pushed right")


func test_separation_ignores_other_lanes_corpses_and_steppers() -> String:
	var a := _maid(0.0, 1)
	var other_lane := _maid(5.0, 2)
	var corpse := _maid(5.0, 1)
	corpse.is_dead = true
	var stepper := _maid(5.0, 1)
	stepper.is_changing_lane = true
	EnemySeparation.apply(a, 0.1)
	var r: String = _T.assert_float_eq(a.global_position.x, 0.0, 0.0001, "nothing to push from")
	if r != "":
		return r
	a.is_changing_lane = true
	stepper.is_changing_lane = false
	EnemySeparation.apply(a, 0.1)
	return _T.assert_float_eq(a.global_position.x, 0.0, 0.0001, "a stepping maid is not pushed")


func test_separation_breaks_exact_overlap_ties_in_opposite_directions() -> String:
	var a := _maid(0.0, 1)
	var b := _maid(0.0, 1)
	EnemySeparation.apply(a, 0.1)
	EnemySeparation.apply(b, 0.1)
	return _T.assert_true(signf(a.global_position.x) == -signf(b.global_position.x) and a.global_position.x != 0.0,
		"stacked maids split opposite ways")
