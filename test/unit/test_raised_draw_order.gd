extends RefCounted

## A body up on raised ground (the wall ledge, scaffolds, platforms) draws BEHIND the
## sidewalk trees; one on the street still draws in front of them.
##
## The bug (player screenshot, main.tscn x~2287): the player stood on the wall ledge
## behind the tree rooted on the sidewalk, yet drew over its canopy. Both sat at z 1
## (z_for(GROUND_LANE) and tree.tscn) and the tie went to tree order, which the
## LaneSortLayer — the scene's last child — always wins.

var _T

const L = preload("res://scripts/lane_system.gd")
const TREE := "res://scenes/tree.tscn"
const LEVELS := ["res://scenes/main.tscn", "res://scenes/boss_room.tscn"]
const STREET := -1.0


## Draw z after z_as_relative chains, the number Godot actually sorts on.
static func _effective_z(n: Node) -> int:
	var z := 0
	var cur: Node = n
	while cur is CanvasItem:
		z += (cur as CanvasItem).z_index
		if not (cur as CanvasItem).z_as_relative:
			break
		cur = cur.get_parent()
	return z


static func _collect(n: Node, path: String, out: Array) -> void:
	if n.scene_file_path == path:
		out.append(n)
	for c in n.get_children():
		_collect(c, path, out)


func test_raised_body_draws_under_every_tree_street_body_does_not() -> String:
	var raised := L.depth_z(L.GROUND_LANE, STREET - 64.0, STREET, true)
	var street := L.depth_z(L.GROUND_LANE, STREET, STREET, false)
	var checked := 0
	for level_path in LEVELS:
		var level: Node = (load(level_path) as PackedScene).instantiate()
		var trees: Array = []
		_collect(level, TREE, trees)
		for t in trees:
			checked += 1
			var tz := _effective_z(t)
			if raised >= tz or street < tz:
				var msg := "%s: %s z %d vs raised body z %d / street body z %d" % [
					level_path, level.get_path_to(t), tz, raised, street]
				level.free()
				return _T.assert_true(false, msg)
		level.free()
	return _T.assert_gt(checked, 0, "found trees to check")


## Road lanes are out in the street, never on raised ground: the flag must not move them.
func test_raised_flag_leaves_road_lanes_alone() -> String:
	for lane in range(L.GROUND_LANE + 1, L.LANE_COUNT):
		var foot := L.floor_y(STREET, lane)
		var r: String = _T.assert_eq(L.depth_z(lane, foot, STREET, true), L.depth_z(lane, foot, STREET),
			"lane %d ignores raised" % lane)
		if r != "":
			return r
	return ""


func test_on_raised_floor_reads_feet_against_the_street() -> String:
	var r: String = _T.assert_true(L.on_raised_floor(false, true, STREET, STREET - 64.0), "on the ledge")
	if r != "":
		return r
	r = _T.assert_false(L.on_raised_floor(true, true, STREET, STREET), "back on the street")
	if r != "":
		return r
	r = _T.assert_false(L.on_raised_floor(false, true, STREET, STREET - L.BASELINE_TOLERANCE * 0.5),
		"tile-seam drift is still the street")
	if r != "":
		return r
	return _T.assert_false(L.on_raised_floor(false, true, INF, -64.0), "nothing is raised before the street is known")


## Mid-air keeps the last answer: a hop on the sidewalk must not duck behind the
## canopy, and a drop off the ledge stays behind it until it lands.
func test_on_raised_floor_holds_while_airborne() -> String:
	var r: String = _T.assert_false(L.on_raised_floor(false, false, STREET, STREET - 80.0), "jump from street")
	if r != "":
		return r
	return _T.assert_true(L.on_raised_floor(true, false, STREET, STREET - 10.0), "falling off the ledge")
