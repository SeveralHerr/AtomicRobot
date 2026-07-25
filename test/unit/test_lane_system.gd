extends RefCounted

# Headless tests for the Lanes static helpers (scripts/lane_system.gd) —
# the pure math underneath the TMNT-style virtual-depth movement.

var _T
const L = preload("res://scripts/lane_system.gd")


func test_lane_constants_are_coherent() -> String:
	var r: String = _T.assert_eq(L.LANE_COUNT, L.FRONT_LANE - L.BACK_LANE + 1, "count matches bounds")
	if r != "":
		return r
	return _T.assert_gt(L.LANE_SPACING, 0.0, "positive spacing")


## Pins the shipped lane count. The rest of the suite is bounds-relative and would
## happily pass with any count, so this is the tripwire that makes adding/removing a
## lane a deliberate edit.
func test_front_lane_is_the_fourth_lane() -> String:
	var r: String = _T.assert_eq(L.LANE_COUNT, 4, "four lanes ship")
	if r != "":
		return r
	return _T.assert_eq(L.FRONT_LANE, 3, "front lane index")


## The walkway band must stay exactly z=1: authored props sit at z=2 (parked-car
## decals, interact labels) and have always drawn over bodies standing there.
func test_ground_lane_keeps_its_bare_z() -> String:
	return _T.assert_eq(L.z_for(L.GROUND_LANE), 1, "walkway stays at z=1")


## Road bands must clear every authored prop z (max 2) and never overlap each other,
## or a body jittered to its lane's near edge could out-sort the whole next lane.
func test_road_lane_bands_are_disjoint_and_clear_of_props() -> String:
	for lane in range(L.GROUND_LANE + 1, L.FRONT_LANE + 1):
		var base := L.z_for(lane)
		var r: String = _T.assert_gt(float(base), 2.0, "lane %d band clears prop z" % lane)
		if r != "":
			return r
		# Widest z any body on this lane can reach.
		var top := base + L.DEPTH_Z_BIAS + int(L.IN_LANE_JITTER)
		if lane < L.FRONT_LANE and top >= L.z_for(lane + 1):
			return "lane %d tops out at z=%d, colliding with lane %d at z=%d" % [lane, top, lane + 1, L.z_for(lane + 1)]
	return ""


## The whole point of depth_z: a body standing nearer the camera draws over one
## standing further back IN THE SAME LANE, whatever their origins are doing. Y-sort
## could not do this — it keys on origin Y, so the player (soles 19.75px below its
## origin) always beat a maid (27px) by a constant 7.25px regardless of real depth.
func test_depth_z_orders_by_foot_line_within_a_lane() -> String:
	var floor_line := -20.75
	var lane := 2
	var back := L.depth_z(lane, L.floor_y(floor_line, lane) - 4.0, floor_line)
	var mid := L.depth_z(lane, L.floor_y(floor_line, lane), floor_line)
	var front := L.depth_z(lane, L.floor_y(floor_line, lane) + 4.0, floor_line)
	if not (back < mid and mid < front):
		return "expected back(%d) < mid(%d) < front(%d)" % [back, mid, front]
	return _T.assert_true(front < L.z_for(lane + 1), "still inside its own lane band")


## A body with no captured floor line has no measurable depth; it must fall back to
## the plain band rather than reading INF/NaN into z.
func test_depth_z_without_a_baseline_falls_back_to_the_band() -> String:
	return _T.assert_eq(L.depth_z(2, 100.0, INF), L.z_for(2), "no baseline means bare band z")


func test_clamp_lane_bounds() -> String:
	var r: String = _T.assert_eq(L.clamp_lane(-5), L.BACK_LANE, "clamp low")
	if r != "":
		return r
	r = _T.assert_eq(L.clamp_lane(99), L.FRONT_LANE, "clamp high")
	if r != "":
		return r
	return _T.assert_eq(L.clamp_lane(1), 1, "in-range passthrough")


func test_is_valid_lane() -> String:
	for lane in range(L.BACK_LANE, L.FRONT_LANE + 1):
		if not L.is_valid_lane(lane):
			return "lane %d should be valid" % lane
	var r: String = _T.assert_false(L.is_valid_lane(L.BACK_LANE - 1), "below range invalid")
	if r != "":
		return r
	return _T.assert_false(L.is_valid_lane(L.FRONT_LANE + 1), "above range invalid")


func test_ground_lane_is_back_lane() -> String:
	return _T.assert_eq(L.GROUND_LANE, L.BACK_LANE, "walkway (physical floor) is the back lane")


func test_y_offset_ground_is_zero_and_front_is_down_screen() -> String:
	var r: String = _T.assert_float_eq(L.y_offset(L.GROUND_LANE), 0.0, 0.001, "ground lane has no offset")
	if r != "":
		return r
	# Each step toward the camera (higher index) moves LANE_SPACING further down-screen (+Y).
	for lane in range(L.BACK_LANE, L.FRONT_LANE):
		var diff := L.y_offset(lane + 1) - L.y_offset(lane)
		r = _T.assert_float_eq(diff, L.LANE_SPACING, 0.001, "lane %d is one spacing below lane %d" % [lane + 1, lane])
		if r != "":
			return r
	return ""


func test_floor_y_applies_offset_to_baseline() -> String:
	var baseline := -20.75
	var r: String = _T.assert_float_eq(L.floor_y(baseline, L.GROUND_LANE), baseline, 0.001, "ground floor == baseline")
	if r != "":
		return r
	return _T.assert_float_eq(L.floor_y(baseline, L.FRONT_LANE), baseline + L.LANE_SPACING * (L.LANE_COUNT - 1), 0.001, "front floor is lowest on screen")


## The whole point of splitting floor line from foot offset: hand the SAME baseline
## to two bodies with different collision boxes and their soles must still land on
## one line. Conflating the two is what put spawner-placed maids 7.25px below
## self-baselined ones on the same lane.
func test_stand_y_puts_different_bodies_soles_on_one_line() -> String:
	var floor_line := -20.75
	var player_feet := 19.75  # player.tscn: 28 x 51.5 box at y=-6
	var maid_feet := 27.0     # meter_maid.tscn: 24 x 48 box at y=+3
	for lane in range(L.BACK_LANE, L.FRONT_LANE + 1):
		var player_y := L.stand_y(floor_line, lane, player_feet)
		var maid_y := L.stand_y(floor_line, lane, maid_feet)
		var r: String = _T.assert_float_eq(
			player_y + player_feet, maid_y + maid_feet, 0.001,
			"lane %d: soles agree" % lane)
		if r != "":
			return r
		# ...and that shared sole line is the lane's floor, not either body's origin.
		r = _T.assert_float_eq(player_y + player_feet, L.floor_y(floor_line, lane), 0.001,
			"lane %d: soles rest on the lane floor" % lane)
		if r != "":
			return r
	return ""


func test_stand_y_with_no_foot_offset_is_floor_y() -> String:
	return _T.assert_float_eq(L.stand_y(-20.75, 2, 0.0), L.floor_y(-20.75, 2), 0.001,
		"zero offset degrades to the raw floor line")


func test_measure_foot_offset_reads_the_body_shape() -> String:
	var body := CharacterBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 51.5)
	cs.shape = rect
	cs.position = Vector2(0, -6)
	body.add_child(cs)
	var offset := L.measure_foot_offset(body)
	body.free()
	# -6 (shape centre) + 25.75 (half height) = 19.75px from origin down to the soles.
	return _T.assert_float_eq(offset, 19.75, 0.001, "player-shaped box measures 19.75")


## An Area2D's shape is a hitbox, not a footprint — counting it would have cars and
## maids standing on their own detection radius.
func test_measure_foot_offset_ignores_area_shapes() -> String:
	var body := Node2D.new()
	var area := Area2D.new()
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 40.0
	cs.shape = circle
	area.add_child(cs)
	body.add_child(area)
	var offset := L.measure_foot_offset(body)
	body.free()
	return _T.assert_float_eq(offset, 0.0, 0.001, "no direct shape means no offset")


## Editor instance scaling changes how far a body's origin sits above its feet, so
## the measurement has to scale with it or scaled enemies drift off the lane line.
func test_measure_foot_offset_respects_body_scale() -> String:
	var body := CharacterBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 48)
	cs.shape = rect
	cs.position = Vector2(0, 3)
	body.add_child(cs)
	body.scale = Vector2(2, 2)
	var offset := L.measure_foot_offset(body)
	body.free()
	return _T.assert_float_eq(offset, 54.0, 0.001, "(3 + 24) * 2 == 54")


## The ground lane rides real floor collision, so a depth offset there would float or
## sink bodies off the walkway — and worse, Enemy._update_lane_floor captures the
## shared baseline on that lane, so a jittered ground body would poison every other
## body's floor line.
func test_in_lane_offset_is_zero_on_the_ground_lane() -> String:
	for i in 20:
		var offset := L.random_in_lane_offset(L.GROUND_LANE)
		var r: String = _T.assert_float_eq(offset, 0.0, 0.0001, "ground lane never jitters")
		if r != "":
			return r
	return ""


func test_in_lane_offset_stays_within_jitter_on_road_lanes() -> String:
	var saw_nonzero := false
	for lane in range(L.GROUND_LANE + 1, L.FRONT_LANE + 1):
		for i in 40:
			var offset := L.random_in_lane_offset(lane)
			if absf(offset) > L.IN_LANE_JITTER:
				return "lane %d offset %f exceeds IN_LANE_JITTER %f" % [lane, offset, L.IN_LANE_JITTER]
			if not is_zero_approx(offset):
				saw_nonzero = true
	return _T.assert_true(saw_nonzero, "road lanes actually vary")


## The jitter must stay well inside one lane step, or a "slight" offset would read as
## the enemy standing in the neighbouring lane while still fighting in this one.
func test_in_lane_jitter_cannot_reach_the_next_lane() -> String:
	return _T.assert_true(L.IN_LANE_JITTER * 2.0 < L.LANE_SPACING,
		"jitter range (%f) must stay under one lane spacing (%f)" % [L.IN_LANE_JITTER * 2.0, L.LANE_SPACING])


func test_z_order_front_lane_draws_on_top() -> String:
	for lane in range(L.BACK_LANE, L.FRONT_LANE):
		if L.z_for(lane) >= L.z_for(lane + 1):
			return "z_for must strictly increase toward the front (lane %d)" % lane
	return ""


func test_scene_gating() -> String:
	var r: String = _T.assert_true(L.scene_has_lanes("res://scenes/main.tscn"), "street level has lanes")
	if r != "":
		return r
	return _T.assert_false(L.scene_has_lanes("res://scenes/boss_room.tscn"), "boss room stays single-plane")
