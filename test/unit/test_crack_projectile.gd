extends RefCounted

# Robot and Cass attack with projectiles, and AttackState returned before its melee
# Crack check, so neither could ever open a secret wall. A shot now chips a closed
# crack it flies through, exactly like a melee blow (one frame per hit, five open).

var _T

const CRACK_SCENE := preload("res://scenes/crack.tscn")
const ROBOT_BULLET := preload("res://scenes/robot_bullet.tscn")
const FLIPFLOP := preload("res://scenes/flipflop_bullet.tscn")
const WALL := Vector2(500, 300)

var _nodes: Array[Node] = []


func teardown() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _add(n: Node) -> Node:
	_tree().root.add_child(n)
	_nodes.append(n)
	return n


func _crack() -> Crack:
	var c: Crack = _add(CRACK_SCENE.instantiate())
	c.global_position = WALL
	return c


## Fires one shot from 60 px right of the wall, flying left at `dy` from its centre,
## and returns it after it has had time to cross the wall.
func _shoot(scene: PackedScene, dy: float = 0.0) -> Node2D:
	var b: Node2D = _add(scene.instantiate())
	b.global_position = WALL + Vector2(60, dy)
	b.dir = -1
	for i in 12:
		await _tree().physics_frame
	return b


func test_flipflop_chips_a_hidden_crack() -> String:
	var c := _crack()
	var b := await _shoot(FLIPFLOP)
	var r: String = _T.assert_eq(c.animated_sprite_2d.frame, 1, "one hit")
	if r != "":
		return r
	return _T.assert_false(is_instance_valid(b) and not b.is_queued_for_deletion(), "the shot is spent")


func test_robot_bullet_chips_a_hidden_crack() -> String:
	var c := _crack()
	await _shoot(ROBOT_BULLET)
	return _T.assert_eq(c.animated_sprite_2d.frame, 1, "one hit")


func test_five_shots_open_the_wall() -> String:
	var c := _crack()
	for i in 5:
		await _shoot(FLIPFLOP)
	var r: String = _T.assert_true(c.is_open(), "open after five shots")
	if r != "":
		return r
	return _T.assert_true(c.interact_label.visible, "claim prompt shown")


func test_shot_flies_through_an_open_hole() -> String:
	var c := _crack()
	for i in 5:
		c.receive_hit()
	var b := await _shoot(FLIPFLOP)
	return _T.assert_true(is_instance_valid(b) and not b.is_queued_for_deletion(),
		"an opened wall no longer eats shots")


func test_shot_well_above_the_crack_misses() -> String:
	var c := _crack()
	await _shoot(FLIPFLOP, -120.0)
	return _T.assert_eq(c.animated_sprite_2d.frame, 0, "street shot under a high crack")


func test_find_crack_needs_the_sweep_to_reach_the_circle() -> String:
	var c := _crack()
	var reach: float = c.hit_radius() + LaneProjectile.HALF_LENGTH
	var r: String = _T.assert_eq(LaneProjectile.find_crack([c], WALL.y, WALL.x + reach + 10, WALL.x + reach + 1),
		null, "sweep stops just short")
	if r != "":
		return r
	return _T.assert_eq(LaneProjectile.find_crack([c], WALL.y, WALL.x + reach + 10, WALL.x + reach - 1),
		c, "sweep edge touches the circle")
