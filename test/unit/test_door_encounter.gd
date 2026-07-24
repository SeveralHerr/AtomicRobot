extends RefCounted

# Headless tests for BuildingDoorEncounter.lane_for_index — the pure function that
# decides which lane each enemy takes as it pours out of the door.

var _T
const E = preload("res://scripts/building_door_encounter.gd")
const L = preload("res://scripts/lane_system.gd")


func test_round_robin_covers_every_lane() -> String:
	var seen := {}
	for i in range(L.LANE_COUNT):
		seen[E.lane_for_index(i)] = true
	return _T.assert_eq(seen.size(), L.LANE_COUNT, "one squad cycle touches every lane")


func test_round_robin_starts_at_the_walkway() -> String:
	return _T.assert_eq(E.lane_for_index(0), L.BACK_LANE, "first enemy out takes the walkway")


func test_round_robin_wraps() -> String:
	var r: String = _T.assert_eq(
		E.lane_for_index(L.LANE_COUNT), E.lane_for_index(0), "wraps after a full cycle")
	if r != "":
		return r
	return _T.assert_eq(
		E.lane_for_index(L.LANE_COUNT + 2), E.lane_for_index(2), "stays in phase")


func test_every_index_yields_a_valid_lane() -> String:
	for i in range(32):
		if not L.is_valid_lane(E.lane_for_index(i)):
			return "lane_for_index(%d) returned an out-of-range lane" % i
	return ""


func test_explicit_pattern_is_honoured() -> String:
	var pattern := [2, 0, 3]
	var r: String = _T.assert_eq(E.lane_for_index(0, pattern), 2, "pattern[0]")
	if r != "":
		return r
	r = _T.assert_eq(E.lane_for_index(1, pattern), 0, "pattern[1]")
	if r != "":
		return r
	return _T.assert_eq(E.lane_for_index(3, pattern), 2, "pattern cycles")


func test_out_of_range_pattern_entries_are_clamped() -> String:
	var pattern := [-4, 99]
	var r: String = _T.assert_eq(E.lane_for_index(0, pattern), L.BACK_LANE, "clamps low")
	if r != "":
		return r
	return _T.assert_eq(E.lane_for_index(1, pattern), L.FRONT_LANE, "clamps high")
