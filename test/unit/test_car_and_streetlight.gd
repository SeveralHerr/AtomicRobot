extends RefCounted

# Cars: a car strikes a body once and then drives on — knockback can shove the player
# out of its hitbox and back in as the car catches up, which used to re-hit them every
# time. Streetlights: the trigger is a vertical column, so a player standing on the
# road below the light (or above it) turns it green, not only one near the lamp head.

var _T

const CAR := preload("res://scenes/car.tscn")
const STREETLIGHT := preload("res://scenes/streetlight.tscn")


class StubPlayer:
	extends "res://scripts/Player.gd"
	var hits := 0
	func receive_hit(_source: Vector2, _damage: int, _knockback: float = 300) -> void:
		hits += 1


var _nodes: Array[Node] = []


func teardown() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _keep(n: Node) -> Node:
	_nodes.append(n)
	return n


func _player(lane: int = Lanes.FRONT_LANE) -> StubPlayer:
	var p := _keep(StubPlayer.new()) as StubPlayer
	p.current_lane = lane
	return p


func test_car_hits_player_only_once_even_after_leaving_and_reentering() -> String:
	var car := _keep(CAR.instantiate())
	(Engine.get_main_loop() as SceneTree).root.add_child(car)
	car.lane = Lanes.FRONT_LANE
	var p := _player()
	car._hit(p)
	car.area_2d.body_exited.emit(p)
	car._hit(p)
	car._hit(p)
	return _T.assert_eq(p.hits, 1, "car hits the player once per pass")


func test_car_ignores_player_in_another_lane() -> String:
	var car := _keep(CAR.instantiate())
	car.lane = Lanes.FRONT_LANE
	var p := _player(Lanes.GROUND_LANE)
	car._hit(p)
	return _T.assert_eq(p.hits, 0, "player on the sidewalk is not hit")


func test_car_still_hits_a_player_who_steps_into_its_lane_later() -> String:
	var car := _keep(CAR.instantiate())
	car.lane = Lanes.FRONT_LANE
	var p := _player(Lanes.GROUND_LANE)
	car._hit(p)
	p.current_lane = Lanes.FRONT_LANE
	car._hit(p)
	return _T.assert_eq(p.hits, 1, "a dodge then a lane change still gets hit")


func _light_with_player_at(offset: Vector2) -> Node:
	var light := _keep(STREETLIGHT.instantiate())
	light.global_position = Vector2(1000, 0)
	var p := _player()
	p.global_position = light.global_position + offset
	light.player = p
	return light


func test_streetlight_triggers_for_player_far_below_it() -> String:
	var light := _light_with_player_at(Vector2(20, 400))
	return _T.assert_true(light.player_in_range(), "player on the road under the light triggers it")


func test_streetlight_triggers_for_player_far_above_it() -> String:
	var light := _light_with_player_at(Vector2(-20, -400))
	return _T.assert_true(light.player_in_range(), "player above the light triggers it")


func test_streetlight_ignores_player_off_to_the_side() -> String:
	var light := _light_with_player_at(Vector2(101, 0))
	return _T.assert_false(light.player_in_range(), "player beyond the radius does not trigger")


func test_streetlight_ignores_missing_player() -> String:
	var light := _keep(STREETLIGHT.instantiate())
	return _T.assert_false(light.player_in_range(), "no player, no trigger")
