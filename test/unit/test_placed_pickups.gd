extends RefCounted

## The level-placed rewards in main.tscn: each sits just above the floor it is
## collected from, close enough that a player standing (or, for the roof heart,
## jumping) there overlaps it. Measured against the real collision, not magic
## numbers, so moving a scaffold drags its reward check along with it.
## Reaching them for real is test/autoplay/placed_pickups.json.

var _T

const MAIN := preload("res://scenes/main.tscn")
const GROUP := "Level/SceneItemsBackground/AtomicRobotBuildingGroup/AtomicBuildingGroup/"
## Player origin stands ~20px above its soles; a pickup whose centre is within this
## band above a floor is touched by anyone standing on it.
const MAX_HOVER := 40.0

var _main: Node


func setup() -> void:
	_main = MAIN.instantiate()


func teardown() -> void:
	_main.free()


## World position without entering the tree (no _ready, no autoload side effects).
func _world(n: Node) -> Vector2:
	var t := Transform2D.IDENTITY
	var c := n
	while c != null:
		if c is Node2D:
			t = (c as Node2D).transform * t
		if c == _main:
			break
		c = c.get_parent()
	return t.origin


## Top edge (world y) and x-span of a floor's first CollisionShape2D rectangle.
func _floor(body_path: String) -> Dictionary:
	var shape := _main.get_node(body_path) as CollisionShape2D
	var rect := shape.shape as RectangleShape2D
	var c := _world(shape)
	return {"top": c.y - rect.size.y * 0.5, "left": c.x - rect.size.x * 0.5, "right": c.x + rect.size.x * 0.5}


func _check_above(pickup_path: String, floor_path: String, max_hover: float) -> String:
	var pk := _main.get_node_or_null(pickup_path)
	if pk == null:
		return "missing " + pickup_path
	var at := _world(pk)
	var f := _floor(floor_path)
	var r: String = _T.assert_true(at.x >= f["left"] and at.x <= f["right"], "%s over its floor (x=%d)" % [pk.name, at.x])
	if r == "":
		var hover: float = f["top"] - at.y
		r = _T.assert_true(hover > 0.0 and hover <= max_hover, "%s hovers %d px above its floor" % [pk.name, hover])
	return r


func test_ledge_powerup_sits_on_the_window_buildings_upper_ledge() -> String:
	return _check_above(GROUP + "LedgePowerup",
		GROUP + "WindowEventBuilding/Collisions/MiddleStaticBody2D/CollisionShape2D", MAX_HOVER)


func test_scaffold_powerup_sits_above_the_tall_scaffold() -> String:
	return _check_above(GROUP + "ScaffoldPowerup", GROUP + "Scaffolding2/StaticBody2D/CollisionShape2D", MAX_HOVER)


## Above the roof scaffold's plank, but low enough to grab with a jump from the roof
## (the plank is out of a standing jump's reach: 94px vs ~84px).
func test_roof_heart_floats_above_the_roof_scaffold() -> String:
	return _check_above(GROUP + "RoofHeart", "Scaffolding/StaticBody2D/CollisionShape2D", MAX_HOVER)


func test_placed_powerups_are_static_and_on_the_ground_lane() -> String:
	for name in ["LedgePowerup", "ScaffoldPowerup"]:
		var pk := _main.get_node(GROUP + name)
		if not pk is PowerupPickup:
			return "%s is not a PowerupPickup" % name
		if not pk.placed:
			return "%s would despawn (placed = false)" % name
		if not PowerupRules.has_id(pk.powerup_id):
			return "%s has unknown buff '%s'" % [name, pk.powerup_id]
		if pk.lane != Lanes.GROUND_LANE:
			return "%s not on the ground lane" % name
	return ""


## One of each buff, so the two rewards don't feel like duplicates.
func test_placed_powerups_offer_both_buffs() -> String:
	var ids := [_main.get_node(GROUP + "LedgePowerup").powerup_id, _main.get_node(GROUP + "ScaffoldPowerup").powerup_id]
	ids.sort()
	var want := PowerupRules.IDS.duplicate()
	want.sort()
	return _T.assert_eq(ids, want, "placed pickups cover every buff")
