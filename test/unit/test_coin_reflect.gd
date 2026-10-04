extends RefCounted

## Coin reflect (parry): a melee blow in the coin's lane sends it back faster, after
## which it hurts enemies in its lane and never the player.

var _T

const COIN_SCENE := preload("res://scenes/coin_bullet.tscn")
const BRIEFCASE_SCENE := preload("res://scenes/briefcase_bullet2.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MAID_SCENE := preload("res://scenes/meter_maid.tscn")

var _nodes: Array[Node] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _add(n: Node) -> Node:
	_tree().root.add_child(n)
	_nodes.append(n)
	n.set_physics_process(false)
	n.set_process(false)
	return n


func teardown() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			Globals.release_attack_slot(n)
			n.free()
	_nodes.clear()


## Player at x=500 facing a coin flying at them from the right, same lane.
func _setup(lane: int = 1) -> Array:
	var p: Player = _add(PLAYER_SCENE.instantiate())
	p.global_position = Vector2(500, 300)
	p.current_lane = lane
	p.health = 5
	var coin: Bullet = _add(COIN_SCENE.instantiate())
	coin.lane = lane
	coin.global_position = Vector2(530, 280)
	coin.linear_velocity = Vector2(-600, 0)
	return [p, coin]


func test_reflect_velocity_flips_and_speeds_up() -> String:
	var v := Bullet.reflect_velocity(Vector2(-600, 20), 1.0, 600.0)
	var r: String = _T.assert_gt(v.x, 600.0, "back to the right, faster")
	if r != "":
		return r
	return _T.assert_true(v.y < 0.0, "a little lift")


func test_coin_is_reflectable_briefcase_is_not() -> String:
	var coin: Bullet = _add(COIN_SCENE.instantiate())
	var r: String = _T.assert_true(coin.is_in_group(Bullet.REFLECT_GROUP), "coin joins the group")
	if r != "":
		return r
	var bc: Bullet = _add(BRIEFCASE_SCENE.instantiate())
	return _T.assert_false(bc.is_in_group(Bullet.REFLECT_GROUP), "boss briefcase stays unparryable")


## The contract with the player's attack: its Area2D must already scan the layer
## the coin's ReflectArea sits on, or reflect() is never called.
func test_player_attack_area_scans_reflect_layer() -> String:
	var p: Player = _add(PLAYER_SCENE.instantiate())
	var coin: Bullet = _add(COIN_SCENE.instantiate())
	var area: Area2D = coin.get_node("ReflectArea")
	var r: String = _T.assert_true(area.monitorable, "reflect area is detectable")
	if r != "":
		return r
	return _T.assert_true((p.area_2d.collision_mask & area.collision_layer) != 0,
		"player attack mask overlaps the reflect layer")


func test_reflect_flips_direction_once() -> String:
	var s := _setup()
	var p: Player = s[0]
	var coin: Bullet = s[1]
	coin.reflect(p)
	var r: String = _T.assert_true(coin.reflected and coin.linear_velocity.x > 0.0, "flies away from the player")
	if r != "":
		return r
	coin.linear_velocity = Vector2(-100, 0)
	coin.reflect(p)
	return _T.assert_eq(coin.linear_velocity, Vector2(-100, 0), "second reflect is a no-op")


func test_other_lane_cannot_reflect() -> String:
	var s := _setup(1)
	var p: Player = s[0]
	var coin: Bullet = s[1]
	p.current_lane = 2
	coin.reflect(p)
	return _T.assert_false(coin.reflected, "swing in another lane misses the coin")


func test_reflected_coin_never_hits_player() -> String:
	var s := _setup()
	var p: Player = s[0]
	var coin: Bullet = s[1]
	coin.reflect(p)
	coin.global_position = p.enemy_attack_position.global_position
	coin._physics_process(0.016)
	coin._on_body_entered(p)
	var r: String = _T.assert_false(coin.has_hit_player, "no hit flag")
	if r != "":
		return r
	return _T.assert_eq(p.health, 5, "player untouched")


func _maid_at(pos: Vector2, lane: int) -> Enemy:
	var e: Enemy = _add(MAID_SCENE.instantiate())
	e.global_position = pos
	e.lane = lane
	return e


func test_reflected_coin_damages_enemy_in_lane() -> String:
	var s := _setup()
	var coin: Bullet = s[1]
	coin.reflect(s[0])
	var e := _maid_at(Vector2(700, 300), 1)
	var hp := e.health
	coin.global_position = e.global_position
	coin._check_enemy_contact()
	var r: String = _T.assert_eq(e.health, hp - Bullet.REFLECT_DAMAGE, "maid takes coin damage")
	if r != "":
		return r
	return _T.assert_true(coin.is_queued_for_deletion(), "coin spent on the hit")


func test_reflected_coin_ignores_enemy_in_other_lane() -> String:
	var s := _setup()
	var coin: Bullet = s[1]
	coin.reflect(s[0])
	var e := _maid_at(Vector2(700, 300), 2)
	var hp := e.health
	coin.global_position = e.global_position
	coin._check_enemy_contact()
	return _T.assert_eq(e.health, hp, "other-lane maid untouched")


func test_unreflected_coin_ignores_enemies() -> String:
	var s := _setup()
	var coin: Bullet = s[1]
	var e := _maid_at(Vector2(700, 300), 1)
	var hp := e.health
	coin.global_position = e.global_position
	coin._physics_process(0.016)
	return _T.assert_eq(e.health, hp, "a thrown coin doesn't hurt its own side")
