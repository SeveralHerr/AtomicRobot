extends RefCounted

## Street side jobs (scripts/objectives/): the pure rules each job is built on, then the
## lifecycle on a real player + real maids — start, win, miss, death, watchdog — with
## the one guarantee every job shares: it ends exactly once and never soft-locks.

var _T
const SO = preload("res://scripts/objectives/street_objective.gd")
const SC = preload("res://scripts/objectives/snatch_chase.gd")
const MD = preload("res://scripts/objectives/meter_defense.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _stage: Node2D
var _p: Player
var _old_scene: Node
var _job: StreetObjective
var _ended: Array = []
var _reports: Array = []
## Global scripted-fight count, isolated per test: an earlier suite leaves an event
## pushed, and a job never starts while one is live.
var _saved_events: int = 0


# --- Pure rules ----------------------------------------------------------------------

func test_job_start_needs_the_mark_and_a_quiet_street() -> String:
	var r: String = _T.assert_false(SO.should_start(990.0, 1000.0, 1, false, false), "short of the mark")
	if r != "":
		return r
	r = _T.assert_true(SO.should_start(1000.0, 1000.0, 1, false, false), "on the mark")
	if r != "":
		return r
	r = _T.assert_false(SO.should_start(1100.0, 1000.0, 1, true, false), "a cut scene has the camera")
	if r != "":
		return r
	return _T.assert_false(SO.should_start(1100.0, 1000.0, 1, false, true), "a door fight is live")


func test_job_start_window_ignores_a_player_far_past_the_mark() -> String:
	var r: String = _T.assert_true(SO.should_start(1000.0 + SO.START_WINDOW, 1000.0, 1, false, false), "edge of window")
	if r != "":
		return r
	return _T.assert_false(SO.should_start(1001.0 + SO.START_WINDOW, 1000.0, 1, false, false), "teleported past")


func test_job_start_rule_honours_a_westbound_mark() -> String:
	var r: String = _T.assert_true(SO.should_start(900.0, 1000.0, -1, false, false), "past it heading west")
	if r != "":
		return r
	return _T.assert_false(SO.should_start(1100.0, 1000.0, -1, false, false), "not yet heading west")


func test_job_watchdog_fires_only_past_the_slack() -> String:
	var r: String = _T.assert_false(SO.overdue(10.0 + SO.WATCHDOG_SLACK - 0.1, 10.0), "inside slack")
	if r != "":
		return r
	return _T.assert_true(SO.overdue(10.0 + SO.WATCHDOG_SLACK, 10.0), "slack spent")


func test_job_thief_escapes_only_far_enough_her_way() -> String:
	var r: String = _T.assert_false(SC.escaped(4000.0, 4880.0, -1, 1000.0), "880 px west: still in reach")
	if r != "":
		return r
	r = _T.assert_true(SC.escaped(3880.0, 4880.0, -1, 1000.0), "1000 px west: gone")
	if r != "":
		return r
	return _T.assert_false(SC.escaped(5880.0, 4880.0, -1, 1000.0), "knocked the wrong way is not an escape")


func test_job_one_blow_or_a_death_catches_the_thief() -> String:
	var r: String = _T.assert_false(SC.caught(12, 12, false), "untouched")
	if r != "":
		return r
	r = _T.assert_true(SC.caught(9, 12, false), "one blow")
	if r != "":
		return r
	return _T.assert_true(SC.caught(12, 12, true), "a car got her")


func test_job_weave_never_stays_put_and_never_takes_the_walkway() -> String:
	for current in range(Lanes.BACK_LANE, Lanes.FRONT_LANE + 1):
		for roll in 12:
			var l := ThiefState.next_weave_lane(current, roll)
			if l == current or l == Lanes.GROUND_LANE or not Lanes.is_valid_lane(l):
				return "from lane %d roll %d -> %d" % [current, roll, l]
	return ""


func test_job_thief_tires_with_every_juke_but_never_stops() -> String:
	var r: String = _T.assert_gt(ThiefState.flee_speed(0), ThiefState.flee_speed(2), "jukes wind her")
	if r != "":
		return r
	r = _T.assert_eq(ThiefState.flee_speed(99), ThiefState.MIN_SPEED, "floor")
	if r != "":
		return r
	# A chase must always be winnable on foot: the player walks at 170 px/s.
	return _T.assert_gt(170.0, ThiefState.flee_speed(0), "slower than the player")


func test_job_thief_jukes_only_at_a_close_same_lane_threat() -> String:
	var r: String = _T.assert_true(ThiefState.threatened(-80.0, true), "close behind on her lane")
	if r != "":
		return r
	r = _T.assert_false(ThiefState.threatened(-80.0, false), "other lane")
	if r != "":
		return r
	return _T.assert_false(ThiefState.threatened(-300.0, true), "far behind")


func test_job_defense_any_clean_car_wins_and_pays_per_car() -> String:
	var r: String = _T.assert_true(MD.outcome(2, 3), "one car clean")
	if r != "":
		return r
	r = _T.assert_false(MD.outcome(3, 3), "every car ticketed")
	if r != "":
		return r
	r = _T.assert_eq(MD.reward_for(1, 3, 300), 600, "two clean cars")
	if r != "":
		return r
	return _T.assert_eq(MD.reward_for(5, 3, 300), 0, "never negative")


func test_job_cars_park_out_of_view_and_only_while_the_job_can_start() -> String:
	var r: String = _T.assert_false(MD.parks_now(2990.0 - MD.PARK_AHEAD - 1.0, 2990.0, 1), "too early")
	if r != "":
		return r
	r = _T.assert_true(MD.parks_now(2990.0 - MD.PARK_AHEAD, 2990.0, 1), "park ahead")
	if r != "":
		return r
	return _T.assert_false(MD.parks_now(2990.0 + SO.START_WINDOW + 1.0, 2990.0, 1), "job can no longer start")


## Parking further ahead than half a screen is what keeps the cars from popping in
## on camera (zoom 2.5 shows 256 world px either side of the player).
func test_job_cars_pull_in_off_screen() -> String:
	return _T.assert_gt(MD.PARK_AHEAD - (3140.0 - 2990.0), 256.0 + 60.0, "nearest car out of view when parked")


func test_job_ticket_maids_travel_in_the_road_and_write_from_the_curb() -> String:
	var r: String = _T.assert_eq(TicketState.lane_for(200.0), TicketState.TRAVEL_LANE, "walking")
	if r != "":
		return r
	r = _T.assert_eq(TicketState.lane_for(-TicketState.CURB_STEP_PX), Lanes.GROUND_LANE, "at the car")
	if r != "":
		return r
	return _T.assert_true(TicketState.TRAVEL_LANE != ParkedCar.LANE, "never travels through the parked cars")


func test_job_traffic_avoids_the_curb_lane_beside_parked_cars() -> String:
	var r: String = _T.assert_eq(AmbientTraffic.road_lane(ParkedCar.LANE, true), ParkedCar.LANE + 1, "moved out")
	if r != "":
		return r
	r = _T.assert_eq(AmbientTraffic.road_lane(ParkedCar.LANE, false), ParkedCar.LANE, "no parked cars")
	if r != "":
		return r
	return _T.assert_eq(AmbientTraffic.road_lane(3, true), 3, "other lanes untouched")


## Every job in the street table can be switched off on its own (the review's
## approve/reject is per job), and every enabled job is a StreetObjective.
func test_job_every_job_in_the_table_is_a_toggleable_objective() -> String:
	for entry: Dictionary in StreetObjectives.JOBS:
		if not entry.has("on"):
			return "job without an 'on' switch: %s" % entry
		var job: Object = entry["script"].new()
		var ok: bool = job is StreetObjective
		for key: String in entry["props"]:
			if not key in job:
				ok = false
		job.free()
		if not ok:
			return "bad job entry %s" % entry
	return ""


## Jobs own the stretch between door fights: no job's trigger may sit inside a door's
## arena (derived from the level, not a hand list), or the job would be held off for
## the whole fight and then spring on a player already walking away.
func test_job_no_job_triggers_inside_a_door_arena() -> String:
	var level: Node = load("res://scenes/main.tscn").instantiate()
	var doors: Array = []
	_collect_doors(level, doors)
	var msg := ""
	if doors.size() < 5:
		msg = "found only %d doors" % doors.size()
	for entry: Dictionary in StreetObjectives.JOBS:
		var x: float = entry["props"]["trigger_x"]
		for d in doors:
			var mouth: float = _world_x(d) + d.get_node("DoorMouth").position.x
			if absf(x - mouth) < d.arena_half_width:
				msg = "trigger %.0f inside the door arena at %.0f" % [x, mouth]
	level.free()
	return msg


func _collect_doors(n: Node, out: Array) -> void:
	if n is BuildingDoorEncounter:
		out.append(n)
	for c in n.get_children():
		_collect_doors(c, out)


## Global x without a tree: sum the Node2D positions up the parents.
func _world_x(n: Node) -> float:
	var x := 0.0
	while n != null:
		if n is Node2D:
			x += (n as Node2D).position.x
		n = n.get_parent()
	return x


# --- Lifecycle (real player, real maids) ------------------------------------------------

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make(job: StreetObjective) -> void:
	_ended = []
	_reports = []
	_saved_events = Globals._active_events
	Globals._active_events = 0
	_stage = Node2D.new()
	_tree().root.add_child(_stage)
	_old_scene = _tree().current_scene
	_tree().current_scene = _stage
	_p = PLAYER_SCENE.instantiate()
	_stage.add_child(_p)
	_p.set_process(false)
	_p.set_physics_process(false)
	_p.lane_floor_y = 0.0
	_p.global_position = Vector2(5000, -20)
	_job = job
	_stage.add_child(_job)
	_job.finished.connect(func(ok: bool) -> void: _ended.append(ok))
	Globals.objective_finished.connect(_on_report)


func _on_report(id: String, ok: bool) -> void:
	_reports.append([id, ok])


func teardown() -> void:
	if Globals.objective_finished.is_connected(_on_report):
		Globals.objective_finished.disconnect(_on_report)
	if _stage == null:
		return
	Globals._active_events = _saved_events
	_tree().current_scene = _old_scene
	for e in _tree().get_nodes_in_group("enemies"):
		Globals.release_attack_slot(e)
	await _tree().process_frame
	_stage.free()
	_stage = null


func _until(cond: Callable, seconds: float = 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func _chase() -> SnatchChase:
	var c := SnatchChase.new()
	c.trigger_x = 5000.0
	c.keys_x = 4880.0
	c.spawn_dist = 60.0
	return c


func test_job_chase_starts_on_the_mark_and_the_thief_grabs_the_keys() -> String:
	var c := _chase()
	_make(c)
	_p.global_position.x = 4990.0
	await _tree().process_frame
	await _tree().process_frame
	var r: String = _T.assert_eq(c.phase, StreetObjective.Phase.WAITING, "short of the mark")
	if r != "":
		return r
	r = _T.assert_true(is_instance_valid(c.keys), "keys lie on the walkway before the job")
	if r != "":
		return r
	_p.global_position.x = 5010.0
	var ok: bool = await _until(func(): return c.phase == StreetObjective.Phase.RUNNING)
	if not ok:
		return "job never started past the mark (event=%s cutscene=%s floor=%s)" % [
			Globals.event_active(), MicroCutscene.playing, _p.lane_floor_y]
	ok = await _until(func(): return c.grabbed)
	if not ok:
		return "thief never grabbed the keys"
	r = _T.assert_true(c.keys.get_parent() == c.thief, "she carries them")
	if r != "":
		return r
	return _T.assert_true(c.thief.enemy_state_machine.current_state is ThiefState, "she is the thief")


func test_job_chase_one_blow_wins_once_and_pays() -> String:
	var c := _chase()
	_make(c)
	await _tree().process_frame  # ScoreSystem stops scoring on the stage swap first
	ScoreSystem.running = true
	var before := ScoreSystem.score
	c.start(_p)
	await _until(func(): return c.grabbed)
	c.thief.receive_hit(1)
	var ok: bool = await _until(func(): return not _ended.is_empty())
	ScoreSystem.running = false
	if not ok:
		return "blow never ended the chase"
	var r: String = _T.assert_eq(_ended, [true], "won exactly once")
	if r != "":
		return r
	r = _T.assert_eq(_reports, [["snatch_chase", true]], "reported once")
	if r != "":
		return r
	r = _T.assert_eq(ScoreSystem.score - before, c.reward_points, "paid the reward")
	if r != "":
		return r
	return _T.assert_true(c.thief.enemy_state_machine.current_state is ChasePlayerState, "she turns on the player")


func test_job_chase_thief_escaping_is_a_miss_and_she_leaves() -> String:
	var c := _chase()
	_make(c)
	c.start(_p)
	await _until(func(): return c.grabbed)
	c.thief.global_position.x = c.keys_x - c.escape_dist - 5.0
	var ok: bool = await _until(func(): return not _ended.is_empty())
	if not ok:
		return "escape never ended the chase"
	var r: String = _T.assert_eq(_ended, [false], "missed once")
	if r != "":
		return r
	return _T.assert_true(await _until(func(): return not is_instance_valid(c.thief)), "she fades off the street")


func test_job_chase_clock_waits_for_the_grab() -> String:
	var c := _chase()
	c.spawn_dist = 400.0
	_make(c)
	c.start(_p)
	await _tree().process_frame
	await _tree().process_frame
	return _T.assert_eq(c.time_left, c.time_limit, "no time lost before she has the keys")


func test_job_chase_runs_out_of_time() -> String:
	var c := _chase()
	_make(c)
	c.time_limit = 0.3
	c.start(_p)
	var ok: bool = await _until(func(): return not _ended.is_empty())
	return _T.assert_true(ok and _ended == [false], "clock ran out: a miss (%s)" % [_ended])


func test_job_death_mid_job_ends_it_quietly_once() -> String:
	var c := _chase()
	_make(c)
	c.start(_p)
	await _tree().process_frame
	c._on_player_death()
	c._on_player_death()
	await _tree().process_frame
	var r: String = _T.assert_eq(_ended, [false], "ended once, as a miss")
	if r != "":
		return r
	return _T.assert_false(is_instance_valid(c.hud), "card gone with the death beat")


func test_job_watchdog_ends_a_job_whose_rules_never_close() -> String:
	var c := _chase()
	c.spawn_dist = 3000.0  # she never reaches the keys: the clock never starts
	_make(c)
	c.start(_p)
	c._age = c.time_limit + SO.WATCHDOG_SLACK
	var ok: bool = await _until(func(): return not _ended.is_empty())
	return _T.assert_true(ok, "watchdog closed the job")


func _defense() -> MeterDefense:
	var d := MeterDefense.new()
	d.trigger_x = 5000.0
	d.car_xs = [5100.0, 5250.0]
	d.maid_count = 2
	d.maid_stagger = 0.0
	d.spawn_past = 60.0
	d.ticket_seconds = 0.2
	return d


func test_job_defense_tickets_every_car_is_a_miss() -> String:
	var d := _defense()
	_make(d)
	d._park(0.0)
	d.start(_p)
	var ok: bool = await _until(func(): return not _ended.is_empty(), 6.0)
	if not ok:
		return "maids never ticketed the cars (tickets=%d)" % d.tickets
	var r: String = _T.assert_eq(_ended, [false], "all ticketed: a miss")
	if r != "":
		return r
	r = _T.assert_eq(d.tickets, 2, "both cars ticketed")
	if r != "":
		return r
	return _T.assert_true(d.cars.all(func(car): return car.ticketed), "slips on both cars")


func test_job_defense_squad_down_with_a_clean_car_wins() -> String:
	var d := _defense()
	d.ticket_seconds = 30.0
	_make(d)
	d._park(0.0)
	await _tree().process_frame  # ScoreSystem stops scoring on the stage swap first
	ScoreSystem.running = true
	var before := ScoreSystem.score
	d.start(_p)
	await _until(func(): return d.maids.size() == 2)
	await _tree().process_frame
	await _tree().process_frame
	for m in d.maids:
		m.receive_hit(99)
	var ok: bool = await _until(func(): return not _ended.is_empty())
	ScoreSystem.running = false
	if not ok:
		return "squad down never ended the job"
	var r: String = _T.assert_eq(_ended, [true], "won")
	if r != "":
		return r
	r = _T.assert_eq(d.reward_points, 2 * d.points_per_car, "both cars pay")
	if r != "":
		return r
	# The KOs score their own kill points on top.
	return _T.assert_gte(ScoreSystem.score - before, d.reward_points, "reward banked")


func test_job_defense_hit_maid_fights_then_goes_back_to_the_cars() -> String:
	var d := _defense()
	d.maid_count = 1
	d.ticket_seconds = 30.0
	d.grudge_seconds = 0.2
	_make(d)
	d._park(0.0)
	d.start(_p)
	await _until(func(): return d.maids.size() == 1 and d.maids[0].enemy_state_machine.current_state is TicketState)
	var m: Enemy = d.maids[0]
	m.receive_hit(1)
	await _tree().process_frame
	await _tree().process_frame
	var r: String = _T.assert_true(m.enemy_state_machine.current_state is ChasePlayerState, "a blow pulls her off the car")
	if r != "":
		return r
	var ok: bool = await _until(func(): return m.enemy_state_machine.current_state is TicketState)
	return _T.assert_true(ok, "left alone, she goes back to writing")
