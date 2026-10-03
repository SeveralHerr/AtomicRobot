extends RefCounted

# Leaves are cheap decoration, so they must stay cheap on the 1 GB Pi cabinet:
# a pooled leaf is out of the physics world, a sleeping leaf stops raycasting,
# and the manager only rescans for clumps once the player has actually moved.

var _T

const LEAF_SCENE := preload("res://scenes/leaf.tscn")

var _nodes: Array[Node] = []


func teardown() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _spawn_leaf() -> DroppedLeaf:
	var leaf: DroppedLeaf = LEAF_SCENE.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(leaf)
	_nodes.append(leaf)
	return leaf


func test_pooled_leaf_does_not_fall() -> String:
	var leaf := _spawn_leaf()
	leaf.reset_for_pool()
	var start := leaf.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for i in 30:
		await tree.physics_frame
	return _T.assert_eq(leaf.global_position, start, "pooled leaf should be out of the physics world")


func test_activated_leaf_is_simulated_again() -> String:
	var leaf := _spawn_leaf()
	leaf.reset_for_pool()
	leaf.activate_from_pool(Vector2(0, -5000))
	var tree := Engine.get_main_loop() as SceneTree
	for i in 30:
		await tree.physics_frame
	var y := leaf.global_position.y
	var r: String = _T.assert_gt(y, -5000.0, "active leaf should fall under gravity")
	if r != "":
		return r
	# Guards against the body snapping back to where it was pooled.
	return _T.assert_true(y < -4900.0, "active leaf should start from its spawn point, got y=%s" % y)


func test_sleeping_leaf_stops_raycasting() -> String:
	var leaf := _spawn_leaf()
	leaf.sleeping = true
	leaf._physics_process(1.0 / 60.0)
	var r: String = _T.assert_false(leaf.floor_raycast.enabled, "sleeping leaf raycast off")
	if r != "":
		return r
	leaf.sleeping = false
	leaf._physics_process(1.0 / 60.0)
	return _T.assert_true(leaf.floor_raycast.enabled, "awake leaf raycast back on")


func test_leaf_manager_rescans_only_after_player_moves() -> String:
	var m := LeafManager.new()
	_nodes.append(m)
	var r: String = _T.assert_true(m.should_rescan(0.0), "first scan always runs")
	if r != "":
		return r
	m.last_spawn_x = 0.0  # as _process records after a scan
	r = _T.assert_false(m.should_rescan(m.rescan_distance - 1.0), "small move: no rescan")
	if r != "":
		return r
	return _T.assert_true(m.should_rescan(m.rescan_distance + 1.0), "moved far enough: rescan")
