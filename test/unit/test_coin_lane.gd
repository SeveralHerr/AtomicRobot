extends RefCounted

## Coins are lane-bound: a coin hurts only a player standing in its lane, a street
## maid throws down HER lane, and a lane step (even mid-tween) dodges.

var _T

const COIN_SCENE := preload("res://scenes/coin_bullet.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MAID_SCENE := preload("res://scenes/meter_maid.tscn")
const WINDOW_MAID_SCENE := preload("res://scenes/meter_maid_window.tscn")

var _nodes: Array[Node] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _add(n: Node) -> Node:
	_tree().root.add_child(n)
	_nodes.append(n)
	if n is Node:
		n.set_physics_process(false)
		n.set_process(false)
	return n


func teardown() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func test_lane_rule() -> String:
	var r: String = _T.assert_true(Bullet.lane_allows_hit(2, 2, false), "same lane hits")
	if r != "":
		return r
	r = _T.assert_false(Bullet.lane_allows_hit(1, 2, false), "other lane never hits")
	if r != "":
		return r
	return _T.assert_false(Bullet.lane_allows_hit(2, 2, true), "mid-step dodges")


func test_street_maid_throws_down_her_own_lane() -> String:
	var p: Player = _add(PLAYER_SCENE.instantiate())
	var e: Enemy = _add(MAID_SCENE.instantiate())
	e.lane = 1
	p.current_lane = 2
	return _T.assert_eq(Utils.coin_lane_for(e, p), 1, "coin keeps the thrower's lane")


func test_window_maid_lobs_onto_the_players_lane() -> String:
	var p: Player = _add(PLAYER_SCENE.instantiate())
	var e: Enemy = _add(WINDOW_MAID_SCENE.instantiate())
	p.current_lane = 3
	return _T.assert_eq(Utils.coin_lane_for(e, p), 3, "lane-locked maid aims at your lane")


## The contact test itself: a coin sitting inside the player's body box only
## connects when the lanes agree. Physics contact used to fire on any lane the
## 51px-tall body overlapped (lanes are 24px apart).
func _coin_in_player(coin_lane: int, player_lane: int, changing: bool) -> Array:
	var p: Player = _add(PLAYER_SCENE.instantiate())
	p.global_position = Vector2(500, 300)
	p.current_lane = player_lane
	p.is_changing_lane = changing
	p.health = 5
	var coin: Bullet = _add(COIN_SCENE.instantiate())
	coin.lane = coin_lane
	coin.global_position = p.enemy_attack_position.global_position
	coin._check_player_contact()
	return [coin.has_hit_player, p]


func test_contact_in_lane_hits() -> String:
	var res := _coin_in_player(1, 1, false)
	return _T.assert_true(res[0], "coin inside the body box, same lane")


func test_contact_other_lane_misses() -> String:
	var res := _coin_in_player(0, 1, false)
	return _T.assert_false(res[0], "coin inside the body box, other lane")


func test_contact_mid_step_misses() -> String:
	var res := _coin_in_player(1, 1, true)
	return _T.assert_false(res[0], "player mid lane-step")


func test_contact_needs_overlap() -> String:
	var p: Player = _add(PLAYER_SCENE.instantiate())
	p.global_position = Vector2(500, 300)
	var coin: Bullet = _add(COIN_SCENE.instantiate())
	coin.global_position = p.global_position + Vector2(40, 0)
	coin._check_player_contact()
	return _T.assert_false(coin.has_hit_player, "40px beside the player is a miss")


func test_landed_coin_is_harmless() -> String:
	var p: Player = _add(PLAYER_SCENE.instantiate())
	p.global_position = Vector2(500, 300)
	var coin: Bullet = _add(COIN_SCENE.instantiate())
	coin.has_landed = true
	coin.global_position = p.enemy_attack_position.global_position
	coin._check_player_contact()
	return _T.assert_false(coin.has_hit_player, "a coin on the floor is a pickup, not a hit")


func test_shadow_shrinks_with_height() -> String:
	var r: String = _T.assert_float_eq(CoinShadow.scale_for_height(0.0), 1.0, 0.001, "full size on the floor")
	if r != "":
		return r
	r = _T.assert_float_eq(CoinShadow.scale_for_height(-10.0), 1.0, 0.001, "below floor clamps")
	if r != "":
		return r
	r = _T.assert_float_eq(CoinShadow.scale_for_height(CoinShadow.FADE_HEIGHT * 2.0), CoinShadow.MIN_SCALE, 0.001, "clamps high")
	if r != "":
		return r
	return _T.assert_gt(CoinShadow.scale_for_height(30.0), CoinShadow.scale_for_height(60.0), "monotonic")
