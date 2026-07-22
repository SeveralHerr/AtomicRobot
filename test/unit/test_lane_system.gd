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
	var r: String = _T.assert_float_eq(L.y_offset(L.GROUND_LANE), 0.0, "ground lane has no offset")
	if r != "":
		return r
	# Each step toward the camera (higher index) moves LANE_SPACING further down-screen (+Y).
	for lane in range(L.BACK_LANE, L.FRONT_LANE):
		var diff := L.y_offset(lane + 1) - L.y_offset(lane)
		r = _T.assert_float_eq(diff, L.LANE_SPACING, "lane %d is one spacing below lane %d" % [lane + 1, lane])
		if r != "":
			return r
	return ""


func test_floor_y_applies_offset_to_baseline() -> String:
	var baseline := -20.75
	var r: String = _T.assert_float_eq(L.floor_y(baseline, L.GROUND_LANE), baseline, "ground floor == baseline")
	if r != "":
		return r
	return _T.assert_float_eq(L.floor_y(baseline, L.FRONT_LANE), baseline + L.LANE_SPACING * (L.LANE_COUNT - 1), "front floor is lowest on screen")


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
