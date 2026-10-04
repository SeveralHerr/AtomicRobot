extends RefCounted

# Ambient traffic: a rare car drives down a random road lane anywhere in the street,
# telegraphed by an edge warning, never two at once, never while a cut scene or a
# scripted fight (door encounter lock) is running, and freed once it is off screen.

var _T

const TRAFFIC := preload("res://scripts/ambient_traffic.gd")


class StubPlayer:
	extends "res://scripts/Player.gd"


var _nodes: Array[Node] = []


func teardown() -> void:
	while Globals.event_active():
		Globals.pop_event()
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _keep(n: Node) -> Node:
	_nodes.append(n)
	return n


func _rng(s: int = 7) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## A spawner in the tree with a stub player at x=2000 and its countdown expired.
func _traffic() -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	var t: Node2D = _keep(TRAFFIC.new())
	var p := _keep(StubPlayer.new()) as StubPlayer
	p.global_position = Vector2(2000, -30)
	p.lane_floor_y = -10.0  # lanes measured: the street has been stood on
	t.player = p
	tree.root.add_child(t)
	t.countdown = 0.0
	return t


func _cars(t: Node) -> Array:
	return t.get_children().filter(func(c: Node) -> bool: return c is Car)


# --- rules -------------------------------------------------------------------

func test_interval_is_rare_and_varied() -> String:
	var r := _rng()
	var lo := INF
	var hi := -INF
	for i in 500:
		var v: float = TRAFFIC.next_interval(r)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var res: String = _T.assert_true(lo >= TRAFFIC.INTERVAL_MIN and hi <= TRAFFIC.INTERVAL_MAX,
		"interval within bounds, saw %.1f..%.1f" % [lo, hi])
	if res != "":
		return res
	res = _T.assert_gte(TRAFFIC.INTERVAL_MIN, 15.0, "not too often: at least 15 s between cars")
	if res != "":
		return res
	return _T.assert_true(lo < TRAFFIC.INTERVAL_MIN + 2.0 and hi > TRAFFIC.INTERVAL_MAX - 2.0,
		"the interval actually varies across its range")


func test_may_spawn_only_when_everything_is_clear() -> String:
	var res: String = _T.assert_true(TRAFFIC.may_spawn(false, false, true, false), "all clear spawns")
	if res != "":
		return res
	res = _T.assert_false(TRAFFIC.may_spawn(true, false, true, false), "not during a cut scene")
	if res != "":
		return res
	res = _T.assert_false(TRAFFIC.may_spawn(false, true, true, false), "not during a locked fight")
	if res != "":
		return res
	res = _T.assert_false(TRAFFIC.may_spawn(false, false, false, false), "not without a live player")
	if res != "":
		return res
	return _T.assert_false(TRAFFIC.may_spawn(false, false, true, true), "never two cars on the road")


func test_spawn_point_gives_the_full_warning_lead() -> String:
	# Driving left, the car starts off the RIGHT edge, LEAD_S of travel away from it.
	var x: float = TRAFFIC.spawn_x(1000.0, 256.0, -1, 300)
	var res: String = _T.assert_float_eq(x, 1256.0 + 300 * TRAFFIC.LEAD_S + TRAFFIC.CAR_HALF_LEN, 0.01,
		"left-driver starts off the right edge")
	if res != "":
		return res
	x = TRAFFIC.spawn_x(1000.0, 256.0, 1, 200)
	return _T.assert_float_eq(x, 744.0 - 200 * TRAFFIC.LEAD_S - TRAFFIC.CAR_HALF_LEN, 0.01,
		"right-driver starts off the left edge")


func test_direction_flips_away_from_the_street_ends() -> String:
	# Near the left end, a right-driver would have to start beyond the street.
	var res: String = _T.assert_eq(TRAFFIC.pick_direction(1, -1500.0, 256.0, 400, -1680.0, 9400.0), -1,
		"near the left end, cars come from the right")
	if res != "":
		return res
	res = _T.assert_eq(TRAFFIC.pick_direction(-1, 9300.0, 256.0, 400, -1680.0, 9400.0), 1,
		"near the right end, cars come from the left")
	if res != "":
		return res
	res = _T.assert_eq(TRAFFIC.pick_direction(1, 4000.0, 256.0, 400, -1680.0, 9400.0), 1,
		"mid-street keeps the rolled direction")
	if res != "":
		return res
	return _T.assert_eq(TRAFFIC.pick_direction(1, 0.0, 256.0, 400, -100.0, 100.0), 0,
		"no room on either side: no car")


func test_despawn_once_past_the_exit_edge() -> String:
	var res: String = _T.assert_false(TRAFFIC.should_despawn(900.0, -1, 1000.0, 256.0), "on screen: keep")
	if res != "":
		return res
	res = _T.assert_false(TRAFFIC.should_despawn(1500.0, -1, 1000.0, 256.0), "still approaching: keep")
	if res != "":
		return res
	res = _T.assert_true(TRAFFIC.should_despawn(1000.0 - 256.0 - TRAFFIC.EXIT_MARGIN - 1.0, -1, 1000.0, 256.0),
		"past the left edge driving left: free")
	if res != "":
		return res
	return _T.assert_true(TRAFFIC.should_despawn(1000.0 - 256.0 - TRAFFIC.FAR_MARGIN - 1.0, 1, 1000.0, 256.0),
		"left far behind by the player: free")


func test_a_fresh_car_is_never_despawned() -> String:
	for dir: int in [-1, 1]:
		var x: float = TRAFFIC.spawn_x(1000.0, 256.0, dir, Car.SPEED_MAX)
		var res: String = _T.assert_false(TRAFFIC.should_despawn(x, dir, 1000.0, 256.0),
			"fastest car (dir %d) survives its own spawn" % dir)
		if res != "":
			return res
	return ""


func test_warning_shows_only_while_the_car_is_off_screen_approaching() -> String:
	var res: String = _T.assert_true(TRAFFIC.warning_visible(1400.0, -1, 1000.0, 256.0), "approaching from the right")
	if res != "":
		return res
	res = _T.assert_false(TRAFFIC.warning_visible(1200.0, -1, 1000.0, 256.0), "on screen: the car is its own warning")
	if res != "":
		return res
	return _T.assert_false(TRAFFIC.warning_visible(600.0, -1, 1000.0, 256.0), "leaving: no warning")


# --- the node ------------------------------------------------------------------

func test_spawns_one_car_on_a_road_lane() -> String:
	var t := _traffic()
	t._physics_process(0.016)
	t._physics_process(0.016)
	var cars := _cars(t)
	var res: String = _T.assert_eq(cars.size(), 1, "one ambient car")
	if res != "":
		return res
	var car: Car = cars[0]
	res = _T.assert_true(car.lane > Lanes.GROUND_LANE and car.lane <= Lanes.FRONT_LANE, "road lane, got %d" % car.lane)
	if res != "":
		return res
	res = _T.assert_eq(car.z_index, Lanes.z_for(car.lane) + Lanes.DEPTH_Z_BIAS, "z-sorted in its lane band")
	if res != "":
		return res
	res = _T.assert_true(car.start, "the car is driving")
	if res != "":
		return res
	res = _T.assert_true(t.countdown >= TRAFFIC.INTERVAL_MIN, "the next car is a full interval away")
	if res != "":
		return res
	return _T.assert_true(t.warning.visible, "the edge warning is up while the car is off screen")


func test_no_car_while_a_fight_has_the_street_and_the_clock_waits() -> String:
	var t := _traffic()
	t.countdown = 3.0
	Globals.push_event()
	for i in 60:
		t._physics_process(0.1)
	var res: String = _T.assert_eq(_cars(t).size(), 0, "no car during the locked fight")
	if res != "":
		return res
	return _T.assert_float_eq(t.countdown, 3.0, 0.001, "the countdown pauses during the fight")


func test_no_second_car_while_one_is_driving() -> String:
	var t := _traffic()
	t._physics_process(0.016)
	t.countdown = 0.0
	t._physics_process(0.016)
	return _T.assert_eq(_cars(t).size(), 1, "never two stacked")


func test_car_is_freed_after_it_leaves_the_screen() -> String:
	var t := _traffic()
	t._physics_process(0.016)
	var car: Car = _cars(t)[0]
	car.global_position.x = t.player.global_position.x \
		+ car.direction * (TRAFFIC.HALF_VIEW_FALLBACK + TRAFFIC.EXIT_MARGIN + 50.0)
	t._physics_process(0.016)
	var res: String = _T.assert_true(car.is_queued_for_deletion(), "off-screen car is freed")
	if res != "":
		return res
	return _T.assert_false(t.warning.visible, "warning drops with the car")


func test_countdown_runs_in_open_play_then_spawns() -> String:
	var t := _traffic()
	t.countdown = 1.0
	t._physics_process(0.5)
	var res: String = _T.assert_float_eq(t.countdown, 0.5, 0.001, "open play runs the clock")
	if res != "":
		return res
	res = _T.assert_eq(_cars(t).size(), 0, "no car before the clock runs out")
	if res != "":
		return res
	t._physics_process(0.6)
	return _T.assert_eq(_cars(t).size(), 1, "a car once it does")
