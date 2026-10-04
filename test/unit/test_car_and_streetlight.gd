extends RefCounted

# Cars: a car strikes a body once and then drives on — knockback can shove the player
# out of its hitbox and back in as the car catches up, which used to re-hit them every
# time. Streetlights: the trigger is a vertical column, so a player standing on the
# road below the light (or above it) turns it green, not only one near the lamp head.

var _T

const CAR := preload("res://scenes/car.tscn")
const STREETLIGHT := preload("res://scenes/streetlight.tscn")
const STREETLIGHT_GD := preload("res://scripts/streetlight.gd")
const MAID := preload("res://scenes/meter_maid.tscn")


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


## Counts engine (.cpp) errors, e.g. Area2D's "Function blocked during in/out signal".
class _EngineErrors extends Logger:
	var mutex := Mutex.new()
	var hits: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING and file.ends_with(".cpp"):
			mutex.lock()
			hits.append("%s:%d %s" % [file.get_file(), line, rationale if rationale != "" else code])
			mutex.unlock()


## Real physics, not a direct _hit(): the bug only exists inside the physics server's
## query flush, where body_entered fires. A car finishing off a maid ran Enemy.die()
## there, and die() flipping player_detection.monitorable logged an engine error.
func test_car_killing_an_enemy_logs_no_engine_error() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var car := _keep(CAR.instantiate())
	car.lane = Lanes.FRONT_LANE
	car.position = Vector2(300, 300)
	tree.root.add_child(car)
	var maid: Enemy = _keep(MAID.instantiate())
	tree.root.add_child(maid)
	maid.set_process(false)
	maid.set_physics_process(false)
	maid.attack_timer.stop()
	maid.lane = Lanes.FRONT_LANE
	maid.health = 1
	maid.global_position = car.area_2d.global_position
	var log := _EngineErrors.new()
	OS.add_logger(log)
	for i in 10:
		await tree.physics_frame
		if maid.is_dead:
			break
	await tree.process_frame
	OS.remove_logger(log)
	Globals.release_attack_slot(maid)
	var r: String = _T.assert_true(maid.is_dead, "the car's body_entered killed the maid")
	if r != "":
		return r
	r = _T.assert_eq(log.hits, [] as Array[String], "no engine errors during the kill")
	if r != "":
		return r
	return _T.assert_false(maid.player_detection.monitorable, "corpse stops being detectable")


## Enemies take the DamageRules car hit (half a maid), not the player-side 1.
func test_car_takes_half_a_maid() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var car := _keep(CAR.instantiate())
	car.lane = Lanes.FRONT_LANE
	tree.root.add_child(car)
	var maid: Enemy = _keep(MAID.instantiate())
	tree.root.add_child(maid)
	maid.set_process(false)
	maid.set_physics_process(false)
	maid.attack_timer.stop()
	maid.lane = Lanes.FRONT_LANE
	car._hit(maid)
	Globals.release_attack_slot(maid)
	return _T.assert_eq(maid.health, maid.max_health - DamageRules.CAR_ENEMY_DAMAGE, "car damage on the maid")


# --- Characterization: how a car moves and where a streetlight puts it -----------

func test_car_is_hidden_until_started() -> String:
	var car := _keep(CAR.instantiate())
	(Engine.get_main_loop() as SceneTree).root.add_child(car)
	car._physics_process(0.5)
	var r: String = _T.assert_false(car.visible, "an unstarted car stays hidden")
	if r != "":
		return r
	return _T.assert_eq(car.position.x, 0.0, "an unstarted car does not move")


func test_started_car_drives_left_at_its_speed() -> String:
	var car := _keep(CAR.instantiate())
	(Engine.get_main_loop() as SceneTree).root.add_child(car)
	car.speed = 200
	car.start = true
	car._physics_process(0.5)
	var r: String = _T.assert_true(car.visible, "a started car shows")
	if r != "":
		return r
	return _T.assert_float_eq(car.position.x, -100.0, 0.01, "200 px/s for 0.5 s, leftward")


func test_car_rolls_a_speed_when_launched_with_zero() -> String:
	var car := _keep(CAR.instantiate())
	(Engine.get_main_loop() as SceneTree).root.add_child(car)
	car.speed = 0
	car.start = true
	car._physics_process(0.01)
	return _T.assert_true(car.speed >= 150 and car.speed <= 450, "speed rolled in 150..450, got %d" % car.speed)


## Review round 3 (approved): an intersection car comes down the player's own lane;
## on the sidewalk, the nearest road lane (cars never drive the sidewalk).
func test_streetlight_car_takes_the_players_lane() -> String:
	for lane in range(Lanes.GROUND_LANE, Lanes.FRONT_LANE + 1):
		var want := maxi(lane, Lanes.GROUND_LANE + 1)
		var r: String = _T.assert_eq(STREETLIGHT_GD.car_lane_for(lane), want, "player lane %d" % lane)
		if r != "":
			return r
	return ""


## Review round 3 (approved): intersection cars hit with no warning. Now the car drives
## in from off screen (engine heard, no on-screen gate) under the same edge sign as
## ambient traffic, on the player's lane.
func test_streetlight_car_is_telegraphed_on_the_players_lane() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var light := _keep(STREETLIGHT.instantiate())
	tree.root.add_child(light)
	var p := _player(2)
	p.global_position = light.global_position
	light.player = p
	light.can_change_state = false  # _process must not turn green and launch a second car
	var car: Car = light._launch_car()
	light._process(0.016)
	var r: String = _T.assert_eq(car.lane, 2, "car on the player's lane")
	if r != "":
		return r
	r = _T.assert_eq(car.get_node_or_null("VisibleOnScreenEnabler2D"), null, "drives in from off screen")
	if r != "":
		return r
	r = _T.assert_true(light.warning.sign.visible, "edge sign up while the car is off screen")
	if r != "":
		return r
	# Mid-screen (the runner's viewport may hold another test's camera).
	car.global_position.x = CarWarning.view_x(light.get_viewport(), p)
	light._process(0.016)
	r = _T.assert_false(light.warning.sign.visible, "the car on screen is its own warning")
	if r != "":
		return r
	# Green over: the light parks its car (hidden, start off) off screen for the red
	# phase. A parked car is no threat: no sign, even though it sits off screen.
	car.global_position.x = CarWarning.view_x(light.get_viewport(), p) + 1000.0
	car.start = false
	light._process(0.016)
	r = _T.assert_false(light.warning.sign.visible, "parked car: no sign")
	if r != "":
		return r
	# The light frees its car after the red phase: tracking a freed car must not error.
	car.free()
	light._process(0.016)
	return _T.assert_false(light.warning.sign.visible, "freed car: sign down, no error")


func test_streetlight_car_rides_the_player_stand_line() -> String:
	var light := _keep(STREETLIGHT.instantiate())
	var p := _player()
	p.lane_floor_y = 100.0
	light.player = p
	return _T.assert_float_eq(Car.road_y(light.player, 2), p.lane_stand_y(2), 0.001, "road y = player's lane stand y")


func test_launched_right_drives_right_mirrored() -> String:
	var car: Car = _keep(CAR.instantiate())
	(Engine.get_main_loop() as SceneTree).root.add_child(car)
	car.launch(2, Vector2(100, 50), 1, 200)
	car._physics_process(0.5)
	var r: String = _T.assert_float_eq(car.global_position.x, 200.0, 0.01, "200 px/s for 0.5 s, rightward")
	if r != "":
		return r
	return _T.assert_true(car.sprite_2d.flip_h, "art mirrored to face right")


func test_car_road_y_before_the_lanes_are_measured() -> String:
	var p := _player()
	p.global_position = Vector2(0, 40)
	return _T.assert_float_eq(Car.road_y(p, 2), 40.0 + Lanes.y_offset(2), 0.001, "player y + lane offset")
