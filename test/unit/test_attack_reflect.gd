extends RefCounted

# "Coins can be reflected with attacks." Contract with coin_bullet.gd (enemy-AI
# owner): a reflectable joins group "reflectable" and exposes reflect(by: Node2D).
# The melee hit frame calls it on every reflectable it overlaps on the player's lane
# (lane only checked when the node has one). Stubs stand in for the coin here.

var _T

const Rig := preload("res://test/unit/player_combat_rig.gd")
const GAP := 40.0
## Leaf layer (8): the coin's ReflectArea sits here, and the swing Area2D already scans it.
const BULLET_LAYER := 128

const STUB_SRC := """
extends %s
var reflected := 0
var by: Node = null
func reflect(who: Node2D) -> void:
	reflected += 1
	by = who
"""
const LANE_SRC := "\nvar lane := 0\n"

var _r: Rig


func setup() -> void:
	_r = Rig.new()


func teardown() -> void:
	_r.free_all()


func _script(base: String, with_lane: bool) -> GDScript:
	var s := GDScript.new()
	s.source_code = STUB_SRC % base + (LANE_SRC if with_lane else "")
	s.reload()
	return s


func _shape() -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 6.0
	cs.shape = c
	return cs


## A coin-like body (CharacterBody2D: the area reports it like the RigidBody coin) on the Bullets layer.
func _body(with_lane: bool, lane: int = 0) -> Node2D:
	var b := CharacterBody2D.new()
	b.set_script(_script("CharacterBody2D", with_lane))
	b.collision_layer = BULLET_LAYER
	b.collision_mask = 0
	b.add_child(_shape())
	b.add_to_group("reflectable")
	if with_lane:
		b.lane = lane
	_r.add(b)
	b.global_position = _r.p.area_2d.get_node("CollisionShape2D").global_position
	return b


func _swing() -> void:
	await _r.step(2)
	_r.tap("Attack")
	await _r.until(func(): return _r.state_name() != "AttackState" and _r.trail.size() > 3, 120)


func test_swing_reflects_a_coin_on_the_players_lane() -> String:
	await _r.spawn("Ryan")
	var c := _body(true, _r.p.current_lane)
	await _swing()
	var r: String = _T.assert_eq(c.reflected, 1, "reflected once per swing")
	if r != "":
		return r
	return _T.assert_eq(c.by, _r.p, "reflect(by) gets the player")


func test_swing_ignores_a_coin_on_another_lane() -> String:
	await _r.spawn("Ryan")
	var c := _body(true, _r.p.current_lane + 1)
	await _swing()
	return _T.assert_eq(c.reflected, 0, "other-lane coin untouched")


func test_laneless_reflectable_is_reflected() -> String:
	await _r.spawn("Ryan")
	var c := _body(false)
	await _swing()
	return _T.assert_eq(c.reflected, 1, "no lane property: always in reach")


func test_reflectable_parent_of_an_area_is_reflected_once() -> String:
	await _r.spawn("Ryan")
	var holder := Node2D.new()
	holder.set_script(_script("Node2D", true))
	holder.lane = _r.p.current_lane
	holder.add_to_group("reflectable")
	var a := Area2D.new()
	a.collision_layer = BULLET_LAYER
	a.collision_mask = 0
	a.add_child(_shape())
	holder.add_child(a)
	_r.add(holder)
	holder.global_position = _r.p.area_2d.get_node("CollisionShape2D").global_position
	await _swing()
	return _T.assert_eq(holder.reflected, 1, "area's reflectable parent hit once")


func test_ungrouped_node_with_reflect_is_left_alone() -> String:
	await _r.spawn("Ryan")
	var c := _body(true, _r.p.current_lane)
	c.remove_from_group("reflectable")
	await _swing()
	return _T.assert_eq(c.reflected, 0, "group membership is the opt-in")


func test_player_swing_scans_the_reflect_area_layer() -> String:
	await _r.spawn("Ryan")
	return _T.assert_true(_r.p.area_2d.get_collision_mask_value(8), "Area2D mask includes layer 8 (coin ReflectArea)")


## The real coin is a body with a ReflectArea child: the swing can see both, and
## must still reflect it only once.
func test_reflectable_seen_as_body_and_area_parent_reflects_once() -> String:
	await _r.spawn("Ryan")
	var c := _body(true, _r.p.current_lane)
	var a := Area2D.new()
	a.collision_layer = BULLET_LAYER
	a.collision_mask = 0
	a.add_child(_shape())
	c.add_child(a)
	await _swing()
	return _T.assert_eq(c.reflected, 1, "one reflect per swing")
