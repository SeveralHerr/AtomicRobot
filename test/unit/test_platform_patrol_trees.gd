extends RefCounted

## Platform maids patrol ledges at canopy height: walking into a street tree reads as
## "walking on top of the tree" (player report, BuildingGroup1 ledge by x 2287).
## PlatformPatrolState turns back at foliage like it does at a wall.

var _T

const TREE := preload("res://scenes/tree.tscn")


func _tree_at(x: float, y: float) -> Sprite2D:
	var t: Sprite2D = TREE.instantiate()
	t.position = Vector2(x, y)
	(Engine.get_main_loop() as SceneTree).root.add_child(t)
	return t


func test_foliage_ahead_blocks_walking_into_canopy() -> String:
	var t := _tree_at(2287, -86)
	var rect := PlatformPatrolState.foliage_rect(t)
	var edge := rect.end.x + PlatformPatrolState.FOLIAGE_LOOKAHEAD - 1.0
	var into := PlatformPatrolState.foliage_ahead(Vector2(edge, -95), -1, [rect])
	var away := PlatformPatrolState.foliage_ahead(Vector2(edge, -95), 1, [rect])
	var far := PlatformPatrolState.foliage_ahead(Vector2(rect.end.x + 80, -95), -1, [rect])
	t.free()
	var r: String = _T.assert_true(into, "heading into the canopy turns")
	if r != "":
		return r
	r = _T.assert_false(away, "heading away from it does not")
	if r != "":
		return r
	return _T.assert_false(far, "a tree far ahead does not")


func test_street_level_walker_ignores_canopy_above() -> String:
	var t := _tree_at(0, -86)
	var rect := PlatformPatrolState.foliage_rect(t)
	t.free()
	# A maid on a roof far above the tree top is not in its foliage.
	return _T.assert_false(PlatformPatrolState.foliage_ahead(Vector2(rect.position.x - 4, rect.position.y - 60), 1, [rect]),
		"canopy only blocks at its own height")


func test_every_level_tree_is_in_the_trees_group() -> String:
	var t := _tree_at(0, 0)
	var ok := t.is_in_group(PlatformPatrolState.TREES_GROUP)
	t.free()
	return _T.assert_true(ok, "tree.gd joins the group the patrol reads")


## A maid already standing in leaves (spawned there) walks on out instead of
## flip-flopping every frame.
func test_maid_already_in_canopy_is_not_turned() -> String:
	var t := _tree_at(0, -86)
	var rect := PlatformPatrolState.foliage_rect(t)
	t.free()
	var feet := rect.get_center() + Vector2(0, PlatformPatrolState.FOLIAGE_PROBE_RISE)
	return _T.assert_false(PlatformPatrolState.foliage_ahead(feet, -1, [rect]),
		"inside the canopy already: keep walking")


## The real platform maid, real physics: patrolling a floor toward a tree,
## she turns back before her front edge reaches the leaves.
func test_platform_maid_turns_at_canopy() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var world := Node2D.new()
	tree.root.add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2 | 32
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(1200, 20)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 10)
	world.add_child(floor_body)
	var t: Sprite2D = TREE.instantiate()
	t.position = Vector2(200, -20)
	world.add_child(t)
	var maid: Node2D = load("res://scenes/meter_maid_platform.tscn").instantiate()
	maid.position = Vector2(0, -2)
	world.add_child(maid)
	var rect := PlatformPatrolState.foliage_rect(t)
	var max_x := -INF
	for i in 240:
		await tree.physics_frame
		max_x = maxf(max_x, maid.global_position.x)
	world.queue_free()
	await tree.process_frame
	return _T.assert_gt(rect.position.x, max_x, "maid stayed left of the canopy (max x %.0f, canopy starts %.0f)" % [max_x, rect.position.x])
