extends RefCounted

# Combat feel: a landed blow spawns hit sparks at the contact point and asks for a
# short hitstop (longer on the kill); a hurt player shakes the camera; an enemy's
# Hit anim, hurt sound and death all fire on the frame the blow lands (they used to
# wait a random 0-200ms, which read as lag). Real Player / meter maid scenes.

var _T

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MAID_SCENE := preload("res://scenes/meter_maid.tscn")
const HIT_FX_SCRIPT := preload("res://scripts/hit_fx.gd")
const U := preload("res://scripts/autoload/utils.gd")


class Dummy:
	extends Node2D
	var is_dead := false
	var hp := 2
	func receive_hit(d: int, _k: float = 200.0) -> void:
		hp -= d
		is_dead = hp <= 0


var _nodes: Array[Node] = []
var _kills_before: int


func setup() -> void:
	_kills_before = Globals.meter_maids_killed


func teardown() -> void:
	_shake().stop()
	_shake().camera = null
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Globals.meter_maids_killed = _kills_before
	U.last_hit_pause_request = 0.0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _shake() -> Node:
	return _tree().root.get_node("ScreenShake")


func _add(n: Node) -> Node:
	_tree().root.add_child(n)
	_nodes.append(n)
	return n


func _player() -> Player:
	var p: Player = _add(PLAYER_SCENE.instantiate())
	p.set_process(false)
	p.set_physics_process(false)
	p.global_position = Vector2(100, 300)
	return p


func _dummy_at(x: float, hp: int) -> Dummy:
	var d := Dummy.new()
	d.hp = hp
	var world: Node2D = _add(Node2D.new())
	world.add_child(d)
	d.global_position = Vector2(x, 300)
	return d


func _sparks_near(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for n in root.find_children("*", "AnimatedSprite2D", true, false):
		if n.get_script() == HIT_FX_SCRIPT:
			out.append(n)
	return out


func test_land_hit_spawns_sparks_between_fighters() -> String:
	var p := _player()
	var d := _dummy_at(160, 5)
	p.land_hit(d)
	var sparks := _sparks_near(d.get_parent())
	var r: String = _T.assert_eq(sparks.size(), 1, "one spark burst per hit")
	if r != "":
		return r
	var x: float = (sparks[0] as Node2D).global_position.x
	return _T.assert_true(x > 100.0 and x < 160.0, "spark on the player-facing side (x=%.1f)" % x)


func test_land_hit_asks_short_hitstop() -> String:
	var p := _player()
	p.land_hit(_dummy_at(160, 5))
	return _T.assert_float_eq(U.last_hit_pause_request, HitFeel.HIT_STOP, 0.0001, "hit hitstop")


func test_killing_blow_asks_longer_hitstop() -> String:
	var p := _player()
	p.land_hit(_dummy_at(160, 1))
	var r: String = _T.assert_float_eq(U.last_hit_pause_request, HitFeel.KILL_STOP, 0.0001, "kill hitstop")
	if r != "":
		return r
	return _T.assert_gt(HitFeel.KILL_STOP, HitFeel.HIT_STOP, "kill freeze longer than a hit")


func test_land_hit_shakes_harder_on_kill() -> String:
	var p := _player()
	_shake().camera = p.camera_2d
	p.land_hit(_dummy_at(160, 5))
	var hit: float = _shake().current_strength()
	_shake().stop()
	p.land_hit(_dummy_at(160, 1))
	var kill: float = _shake().current_strength()
	var r: String = _T.assert_gt(hit, 0.0, "a hit shakes")
	if r != "":
		return r
	return _T.assert_gt(kill, hit, "a kill shakes harder")


func test_contact_point_faces_the_attacker() -> String:
	var left := HitFeel.contact_point(Vector2(0, 0), Vector2(100, 0))
	var right := HitFeel.contact_point(Vector2(200, 0), Vector2(100, 0))
	var r: String = _T.assert_true(left.x < 100.0, "attacker on the left -> spark left of target")
	if r != "":
		return r
	return _T.assert_true(right.x > 100.0, "attacker on the right -> spark right of target")


func test_player_hurt_shakes_camera() -> String:
	var p := _player()
	_shake().camera = p.camera_2d
	p.receive_hit(p.global_position + Vector2(-20, 0), 1)
	return _T.assert_float_eq(_shake().current_strength(), 6.0, 0.001, "hurt shake strength")


func test_enemy_hit_reacts_same_frame() -> String:
	var e: Enemy = _add(MAID_SCENE.instantiate())
	e.set_physics_process(false)
	e.health = 5
	e.receive_hit(1)
	return _T.assert_eq(e.animation_player.current_animation, "Hit", "Hit anim on the hit frame")


func test_enemy_hit_sound_same_frame() -> String:
	var e: Enemy = _add(MAID_SCENE.instantiate())
	e.set_physics_process(false)
	e.health = 5
	e.receive_hit(1)
	return _T.assert_true(e.receive_hit_audio.playing, "hurt sound on the hit frame")


func test_enemy_dies_same_frame() -> String:
	var e: Enemy = _add(MAID_SCENE.instantiate())
	e.set_physics_process(false)
	e.health = 1
	e.receive_hit(1)
	return _T.assert_true(e.is_dead, "killing blow kills on the hit frame")
