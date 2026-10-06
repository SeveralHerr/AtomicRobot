extends RefCounted

## Street side jobs (scripts/objectives/): the pure rules each job is built on, the job
## table, and its placement against the level's door arenas. The lifecycle on a real
## player and real maids lives in test_street_jobs_live.gd.

var _T
const SO = preload("res://scripts/objectives/street_objective.gd")
const SC = preload("res://scripts/objectives/snatch_chase.gd")
const MD = preload("res://scripts/objectives/meter_defense.gd")



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


## Leaving cars head away from the player and always end out of view: a fixed 760 px
## westward drive passed through the fight and vanished on screen beside the player.
func test_job_cars_leave_away_from_the_player_and_out_of_view() -> String:
	for car_x: float in [3140.0, 3330.0, 3540.0]:
		for px in range(2700, 4000, 25):
			var dir := ParkedCar.leave_dir(car_x, px)
			if (car_x - px) * dir < 0.0:
				return "car %.0f drives toward the player at %d" % [car_x, px]
			var end_x := car_x + dir * ParkedCar.LEAVE_PX
			if absf(end_x - px) < ParkedCar.OFFSCREEN_PX:
				return "car %.0f ends in view (%.0f) of the player at %d" % [car_x, end_x, px]
	return ""


## The card arrow names the nearest trouble only while it is off screen.
func test_job_card_arrow_points_at_off_screen_trouble_only() -> String:
	var r: String = _T.assert_eq(MD.arrow_for(3000.0, [3540.0, 3900.0] as Array[float]), 1, "squad off to the right")
	if r != "":
		return r
	r = _T.assert_eq(MD.arrow_for(3000.0, [3150.0, 2500.0] as Array[float]), 0, "nearest one on screen")
	if r != "":
		return r
	r = _T.assert_eq(MD.arrow_for(3000.0, [2600.0] as Array[float]), -1, "behind")
	if r != "":
		return r
	return _T.assert_eq(MD.arrow_for(3000.0, [] as Array[float]), 0, "nothing to point at")


## A win stamp leaves the three car pips readable (which cars were saved).
func test_job_win_stamp_leaves_the_pips_readable() -> String:
	var pips_end := 26.0 + 2 * 40.0 + 32.0
	for word in ["+300", "+600", "+900"]:
		var w := ComicStyle.DISPLAY.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, ObjectiveHud.STAMP_PX).x
		var left := ObjectiveHud.stamp_centre(w).x - (w + 28.0) * 0.5
		if left <= pips_end:
			return "stamp %s starts at x %.0f, over the pips (end %.0f)" % [word, left, pips_end]
	return ""


func test_job_last_ticket_leaves_the_word_to_the_miss_stripe() -> String:
	var r: String = _T.assert_true(MD.pops_word(2, 3), "second of three")
	if r != "":
		return r
	return _T.assert_false(MD.pops_word(3, 3), "the last one")


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
