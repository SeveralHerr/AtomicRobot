extends RefCounted

# Robot's bullets and Cass's flip-flops used to hit only via Area2D overlap at the
# shooter's height. A maid on the right lane but standing at the wrong y (road height
# while lane == 0) was untouchable, so ranged characters could never clear a door
# arena. The hit test is now lane + x; only lane-locked maids (window/platform, up on
# the building) still need real vertical overlap.

var _T

const MAID_SCENE := preload("res://scenes/meter_maid.tscn")
const ROBOT_BULLET := preload("res://scenes/robot_bullet.tscn")
const FLIPFLOP := preload("res://scenes/flipflop_bullet.tscn")

var _maids: Array[Enemy] = []


func setup() -> void:
	_maids.clear()


func teardown() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	for m in _maids:
		if is_instance_valid(m):
			m.free()


func _maid(x: float, y: float, lane: int, locked := false) -> Enemy:
	var m: Enemy = MAID_SCENE.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	m.set_process(false)
	m.set_physics_process(false)
	m.lane = lane
	m.lane_locked = locked
	m.global_position = Vector2(x, y)
	_maids.append(m)
	return m


func test_hits_same_lane_maid_at_wrong_height() -> String:
	var m := _maid(110.0, 10.0, 0)
	var hit := LaneProjectile.find_target([m], 0, -47.0, 100.0, 110.0, 1)
	return _T.assert_eq(hit, m, "lane 0 maid at road height must still be hittable from lane 0")


func test_ignores_other_lane_maid_in_line() -> String:
	var m := _maid(105.0, -47.0, 1)
	var hit := LaneProjectile.find_target([m], 0, -47.0, 100.0, 110.0, 1)
	return _T.assert_eq(hit, null, "other lane must never be hit")


func test_ignores_maid_outside_swept_x() -> String:
	var m := _maid(200.0, -47.0, 0)
	var hit := LaneProjectile.find_target([m], 0, -47.0, 100.0, 110.0, 1)
	return _T.assert_eq(hit, null, "maid far ahead of this frame's sweep")


func test_hits_maid_whose_body_edge_reaches_the_sweep() -> String:
	# Maid body is 24 wide (half 12) and the shot is 22 long (half 11): centres 23 px
	# past either end of the sweep still touch it, 24 px do not.
	var right := _maid(133.0, -47.0, 0)
	var r: String = _T.assert_eq(LaneProjectile.find_target([right], 0, -47.0, 100.0, 110.0, 1), right,
		"right body edge counts toward contact")
	if r != "":
		return r
	var left := _maid(77.0, -47.0, 0)
	r = _T.assert_eq(LaneProjectile.find_target([left], 0, -47.0, 110.0, 100.0, -1), left,
		"left body edge counts toward contact")
	if r != "":
		return r
	right.global_position.x = 134.5
	return _T.assert_eq(LaneProjectile.find_target([right], 0, -47.0, 100.0, 110.0, 1), null,
		"just out of reach misses")


func test_ignores_dead_maid() -> String:
	var m := _maid(105.0, -47.0, 0)
	m.is_dead = true
	var hit := LaneProjectile.find_target([m], 0, -47.0, 100.0, 110.0, 1)
	return _T.assert_eq(hit, null, "corpses don't eat bullets")


func test_lane_locked_maid_needs_vertical_overlap() -> String:
	var high := _maid(105.0, -200.0, 0, true)
	var r: String = _T.assert_eq(LaneProjectile.find_target([high], 0, -47.0, 100.0, 110.0, 1), null,
		"window maid up on the building must not be shot from the street")
	if r != "":
		return r
	var level := _maid(105.0, -47.0, 0, true)
	return _T.assert_eq(LaneProjectile.find_target([level], 0, -47.0, 100.0, 110.0, 1), level,
		"lane-locked maid at bullet height is still hittable")


func test_picks_nearest_maid_along_direction() -> String:
	var far := _maid(109.0, -47.0, 0)
	var near := _maid(101.0, -47.0, 0)
	var r: String = _T.assert_eq(LaneProjectile.find_target([far, near], 0, -47.0, 100.0, 110.0, 1), near,
		"rightward shot hits the first maid it reaches")
	if r != "":
		return r
	r = _T.assert_eq(LaneProjectile.find_target([near, far], 0, -47.0, 100.0, 110.0, 1), near,
		"list order must not decide the target")
	if r != "":
		return r
	return _T.assert_eq(LaneProjectile.find_target([far, near], 0, -47.0, 110.0, 100.0, -1), far,
		"leftward shot hits the first maid it reaches")


## The real scenes must use the shared lane hit test, not their old Area2D.
func test_both_ranged_projectiles_are_lane_projectiles() -> String:
	for scene: PackedScene in [ROBOT_BULLET, FLIPFLOP]:
		var b: Node = scene.instantiate()
		var ok := b is LaneProjectile
		b.free()
		if not ok:
			return _T.assert_true(false, "%s must extend LaneProjectile" % scene.resource_path)
	return ""


# --- Cass's flip-flop: fast and pushes back (player feedback: "most enemies close to
# melee before a second hit") ---------------------------------------------------

func test_flipflop_outpaces_robot_bullet() -> String:
	var f: LaneProjectile = FLIPFLOP.instantiate()
	var b: LaneProjectile = ROBOT_BULLET.instantiate()
	var r: String = _T.assert_gt(f.speed, b.speed, "flip-flop speed vs bullet")
	f.free()
	b.free()
	return r


func test_flipflop_knocks_the_maid_back_along_the_throw() -> String:
	var m := _maid(130.0, 10.0, 0)
	var f: FlipflopBullet = FLIPFLOP.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(f)
	f.global_position = Vector2(100.0, -47.0)
	f.dir = 1
	f._hit(m)
	var r: String = _T.assert_float_eq(m.knockback_velocity.x, FlipflopBullet.KNOCKBACK, 0.5,
		"pushed straight back, full strength")
	if r != "":
		return r
	return _T.assert_gt(FlipflopBullet.KNOCKBACK, 200.0, "harder than a melee blow's 200")


func test_flipflop_does_not_shove_the_boss() -> String:
	var boss: FinalBoss = preload("res://scenes/final_boss.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(boss)
	_maids.append(boss)
	boss.set_physics_process(false)
	var f: FlipflopBullet = FLIPFLOP.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(f)
	f.dir = 1
	f._hit(boss)
	return _T.assert_eq(boss.knockback_velocity, Vector2.ZERO, "the boss is planted")
