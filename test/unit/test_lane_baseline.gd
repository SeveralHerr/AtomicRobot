extends RefCounted

# Headless tests for the LEVEL BASELINE REGISTRY (scripts/lane_system.gd).
#
# Regression cover for the multi-ground-layer bug: main.tscn stacks several colliding
# TileMapLayers — the walkway at Y=-1, raised building ledges at Y=-33 and Y=-65 — and
# every one of them satisfies is_on_floor(). Bodies used to re-capture the lane baseline
# from their own floor contact each frame, so stepping onto a ledge at X~2600 lifted the
# whole lane stack 62.5px (2.6 lane widths) up-screen. The registry answers with ONE
# value per scene, so a second contact on different geometry changes nothing.
#
# These drive the *_on_root entry points with a detached scene root: the unit runner's
# tree is never entered, so nodes there report is_inside_tree() == false and the
# node-based wrappers have no current_scene to find.

var _T
const L = preload("res://scripts/lane_system.gd")

# Real surface heights measured out of main.tscn (tools/dump_level.gd).
const WALKWAY_Y := -1.0
const LEDGE_A_Y := -33.0
const LEDGE_B_Y := -65.0

var _root: Node2D = null


func setup() -> void:
	_root = Node2D.new()
	_root.name = "BaselineTestScene"


func teardown() -> void:
	if _root != null and is_instance_valid(_root):
		_root.free()
	_root = null


## Author the level's walkway line the way main.tscn does.
func _add_marker(parent: Node, y: float) -> void:
	var marker := Marker2D.new()
	marker.name = L.BASELINE_MARKER_NAME
	marker.position = Vector2(0.0, y)
	parent.add_child(marker)


func test_unseeded_scene_has_no_baseline() -> String:
	return _T.assert_false(is_finite(L.baseline_on_root(_root)), "nothing established yet")


func test_first_seed_is_kept_and_returned() -> String:
	var seeded: float = L.seed_on_root(_root, WALKWAY_Y)
	var r: String = _T.assert_float_eq(seeded, WALKWAY_Y, 0.001, "seed returns what it stored")
	if r != "":
		return r
	return _T.assert_float_eq(L.baseline_on_root(_root), WALKWAY_Y, 0.001, "and it reads back")


## THE BUG. A body that walks from the walkway onto a raised ledge offers the ledge's
## floor line; the registry must hand back the walkway line it already has.
func test_standing_on_a_raised_ledge_does_not_move_the_baseline() -> String:
	L.seed_on_root(_root, WALKWAY_Y)
	for ledge in [LEDGE_A_Y, LEDGE_B_Y]:
		var got: float = L.seed_on_root(_root, ledge)
		var r: String = _T.assert_float_eq(got, WALKWAY_Y, 0.001,
			"ledge at Y=%.0f must not rebase the walkway" % ledge)
		if r != "":
			return r
	return _T.assert_float_eq(L.baseline_on_root(_root), WALKWAY_Y, 0.001, "walkway line survives")


## The same thing stated in the units the player actually sees: every lane floor stays
## put. Pre-fix, the lane 1-3 floors rose 62.5px with the baseline and the road lanes
## ended up hanging in mid-air above the street.
func test_lane_floors_do_not_move_when_a_body_climbs() -> String:
	L.seed_on_root(_root, WALKWAY_Y)
	var before: Array[float] = []
	for lane in range(L.BACK_LANE, L.FRONT_LANE + 1):
		before.append(L.floor_y(L.baseline_on_root(_root), lane))

	L.seed_on_root(_root, LEDGE_B_Y)

	for lane in range(L.BACK_LANE, L.FRONT_LANE + 1):
		var now := L.floor_y(L.baseline_on_root(_root), lane)
		var r: String = _T.assert_float_eq(now, before[lane], 0.001,
			"lane %d floor moved %.1fpx" % [lane, before[lane] - now])
		if r != "":
			return r
	return ""


## A level that authors the marker is authoritative from frame zero — a body that
## happens to touch down on a ledge first can't get in ahead of it.
func test_authored_marker_wins_over_a_body_contact() -> String:
	_add_marker(_root, WALKWAY_Y)
	var got: float = L.seed_on_root(_root, LEDGE_B_Y)
	return _T.assert_float_eq(got, WALKWAY_Y, 0.001, "authored marker beats a ledge contact")


## Only a marker at the scene ROOT counts. A stray node of that name deeper in the tree
## (a prop's child, say) must not silently become the level's floor line.
func test_marker_is_only_read_from_the_scene_root() -> String:
	var holder := Node2D.new()
	_root.add_child(holder)
	_add_marker(holder, LEDGE_B_Y)
	return _T.assert_false(is_finite(L.baseline_on_root(_root)), "nested marker is ignored")


## Marker Y is read in WORLD space: a level whose root carries a transform would
## otherwise get a floor line off by exactly that transform.
func test_marker_is_read_in_world_space() -> String:
	_root.position = Vector2(0.0, 100.0)
	_add_marker(_root, WALKWAY_Y)
	return _T.assert_float_eq(L.baseline_on_root(_root), WALKWAY_Y + 100.0, 0.001, "global Y")


## A body outside any scene has nothing to ask, and must say "unknown" rather than
## crashing or inventing a floor line.
func test_missing_root_reports_no_baseline() -> String:
	var r: String = _T.assert_false(is_finite(L.baseline_on_root(null)), "null root reads INF")
	if r != "":
		return r
	return _T.assert_false(is_finite(L.seed_on_root(null, WALKWAY_Y)), "null root cannot seed")


## Garbage in must not become the level's floor line and poison every lane.
func test_non_finite_candidate_is_rejected() -> String:
	var r: String = _T.assert_false(is_finite(L.seed_on_root(_root, INF)), "INF is not a floor")
	if r != "":
		return r
	return _T.assert_float_eq(L.seed_on_root(_root, WALKWAY_Y), WALKWAY_Y, 0.001,
		"a real value still seeds afterwards")


## The value lives on the scene instance, so a reloaded level starts clean instead of
## inheriting the floor line of the run before it.
func test_baseline_does_not_leak_between_scenes() -> String:
	L.seed_on_root(_root, WALKWAY_Y)
	var reloaded := Node2D.new()
	var r: String = _T.assert_false(is_finite(L.baseline_on_root(reloaded)), "fresh scene is clean")
	reloaded.free()
	return r
