extends RefCounted

# Road-lane bodies ignore Ground, so they walk in front of a walkway prop (the crate
# stack at x~2858 in building_group_1). Lanes.walkway_blocked() is what stops them
# stepping back onto the walkway INSIDE that prop, where re-enabled collision would
# embed them.

var _T

var _body: CharacterBody2D
var _shape: CollisionShape2D
var _props: Array[StaticBody2D] = []


func setup() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	_body = CharacterBody2D.new()
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 50)
	_shape.shape = rect
	_shape.position = Vector2(0, -25)  # origin at the soles
	_body.add_child(_shape)
	tree.root.add_child(_body)


func teardown() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	_body.free()
	for p in _props:
		p.free()
	_props.clear()


func _prop(layer: int, center: Vector2, size: Vector2, one_way := false) -> void:
	var sb := StaticBody2D.new()
	sb.collision_layer = layer
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.one_way_collision = one_way
	sb.add_child(cs)
	sb.global_position = center
	(Engine.get_main_loop() as SceneTree).root.add_child(sb)
	_props.append(sb)


func _settle() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in 2:
		await tree.physics_frame


func test_blocked_inside_ground_crate() -> String:
	_prop(2, Vector2(100, -77), Vector2(95, 154))  # crate stack resting on y=0
	await _settle()
	return _T.assert_true(Lanes.walkway_blocked(_body, _shape, Vector2(100, 0)), "standing inside the crate")


func test_clear_beside_crate() -> String:
	_prop(2, Vector2(100, -77), Vector2(95, 154))
	await _settle()
	return _T.assert_false(Lanes.walkway_blocked(_body, _shape, Vector2(170, 0)), "a body-width past the crate")


func test_resting_on_walkway_floor_is_not_blocked() -> String:
	_prop(2, Vector2(0, 16), Vector2(800, 32))  # walkway tile row, top at y=0
	await _settle()
	return _T.assert_false(Lanes.walkway_blocked(_body, _shape, Vector2(0, 0)), "soles touching the floor")


func test_one_way_awning_overhead_is_not_blocked() -> String:
	_prop(32, Vector2(0, -55), Vector2(700, 10), true)  # Platforms layer awning at head height
	await _settle()
	return _T.assert_false(Lanes.walkway_blocked(_body, _shape, Vector2(0, 0)), "one-way platform overhead")


func test_wall_layer_is_ignored() -> String:
	_prop(64, Vector2(0, -77), Vector2(20, 154))  # Wall: already solid on every lane
	await _settle()
	return _T.assert_false(Lanes.walkway_blocked(_body, _shape, Vector2(0, 0)), "wall layer is not a walkway solid")
