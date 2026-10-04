extends RefCounted

# Characterization of Enemy's body reactions: facing, knockback (direction and decay),
# getting hit, and the die() bookkeeping. Pins behaviour before it moved out of
# enemy.gd into collaborators.

var _T

const MAID_SCENE := preload("res://scenes/meter_maid.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _nodes: Array[Node] = []
var _kills_before: int


func setup() -> void:
	_kills_before = Globals.meter_maids_killed


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _maid() -> Enemy:
	var e: Enemy = MAID_SCENE.instantiate()
	_tree().root.add_child(e)
	_nodes.append(e)
	e.set_process(false)
	e.set_physics_process(false)
	e.attack_timer.stop()
	return e


func teardown() -> void:
	await _tree().process_frame
	for n in _nodes:
		if is_instance_valid(n):
			Globals.release_attack_slot(n)
			n.free()
	_nodes.clear()
	Globals.meter_maids_killed = _kills_before


func test_set_facing_mirrors_the_basis_and_keeps_scale() -> String:
	var e := _maid()
	var sx: float = e.transform.x.x
	e.set_facing(-1)
	var r: String = _T.assert_eq(e.facing, -1, "facing left")
	if r != "":
		return r
	r = _T.assert_float_eq(e.transform.x.x, -sx, 0.0001, "x column mirrored")
	if r != "":
		return r
	e.set_facing(0)
	r = _T.assert_eq(e.facing, -1, "0 is a no-op")
	if r != "":
		return r
	e.set_facing(1)
	return _T.assert_float_eq(e.transform.x.x, sx, 0.0001, "flips back exactly")


func test_face_towards_respects_deadzone() -> String:
	var e := _maid()
	e.global_position = Vector2(100, 0)
	e.face_towards(99.0)
	var r: String = _T.assert_eq(e.facing, 1, "1px away is 'on top of us'")
	if r != "":
		return r
	e.face_towards(50.0)
	return _T.assert_eq(e.facing, -1, "turns toward a target on the left")


func test_knockback_without_player_goes_backwards_off_facing() -> String:
	var e := _maid()
	e.set_facing(-1)
	e._apply_knockback(150.0)
	var r: String = _T.assert_eq(e.knockback_velocity, Vector2(150.0, 0.0), "pushed opposite its facing")
	if r != "":
		return r
	return _T.assert_float_eq(e.velocity.y, -50.0, 0.001, "small hop")


func test_knockback_with_player_pushes_away_from_player() -> String:
	var e := _maid()
	var p: Player = PLAYER_SCENE.instantiate()
	_tree().root.add_child(p)
	_nodes.append(p)
	p.set_process(false)
	p.set_physics_process(false)
	p.global_position = Vector2(200, 0)
	e.global_position = Vector2(100, 0)
	e._apply_knockback(100.0)
	return _T.assert_true(e.knockback_velocity.is_equal_approx(Vector2(-100.0, 0.0)), "away from the player: %s" % e.knockback_velocity)


func test_knockback_decay_feeds_velocity_then_shrinks() -> String:
	var e := _maid()
	e.knockback_velocity = Vector2(200, 0)
	e.velocity = Vector2.ZERO
	e._apply_knockback_decay(0.1)
	var r: String = _T.assert_float_eq(e.velocity.x, 20.0, 0.001, "kb * delta added")
	if r != "":
		return r
	return _T.assert_float_eq(e.knockback_velocity.x, 120.0, 0.001, "decays 800 px/s")


func test_knockback_decay_applies_friction_once_spent() -> String:
	var e := _maid()
	e.knockback_velocity = Vector2(5, 0)
	e.velocity = Vector2(100, 0)
	e._apply_knockback_decay(0.1)
	# 100 + 0.5 from the kb, then friction 300 * 0.1 = 30 toward zero.
	return _T.assert_float_eq(e.velocity.x, 70.5, 0.001, "friction when kb is minimal")


func test_receive_hit_damages_and_knocks_back() -> String:
	var e := _maid()
	e.health = 3
	e.receive_hit(1, 120.0)
	var r: String = _T.assert_eq(e.health, 2, "damage applied")
	if r != "":
		return r
	return _T.assert_float_eq(e.knockback_velocity.length(), 120.0, 0.001, "knocked back")


func test_receive_hit_on_corpse_is_ignored() -> String:
	var e := _maid()
	e.health = 3
	e.is_dead = true
	e.receive_hit(1)
	var r: String = _T.assert_eq(e.health, 3, "corpse doesn't bleed health")
	if r != "":
		return r
	return _T.assert_eq(e.knockback_velocity, Vector2.ZERO, "corpse isn't knocked around")


func test_die_counts_once_and_stops_interacting() -> String:
	var e := _maid()
	var kills := Globals.meter_maids_killed
	e.velocity = Vector2(50, 50)
	e.die()
	e.die()
	var r: String = _T.assert_eq(Globals.meter_maids_killed, kills + 1, "counted exactly once")
	if r != "":
		return r
	r = _T.assert_true(e.is_dead, "dead")
	if r != "":
		return r
	r = _T.assert_eq(e.velocity, Vector2.ZERO, "stopped")
	if r != "":
		return r
	r = _T.assert_false(e.player_detection.monitoring, "stops detecting")
	if r != "":
		return r
	return _T.assert_false(e.get_collision_layer_value(3), "off the enemy layer")
