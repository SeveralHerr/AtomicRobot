extends RefCounted

# A ground-lane maid that ends up standing on the walkway tiles' collision down in the
# road strip (after knockback or a door walk-out) used to keep lane == 0 and drag her
# own baseline down to match. She re-derives her lane from her feet instead.

var _T

const MAID_SCENE := preload("res://scenes/meter_maid.tscn")
const STREET := -28.0

var _e: Enemy
var _floor: StaticBody2D


func setup() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	_floor = StaticBody2D.new()
	_floor.collision_layer = 2  # Ground
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 20)
	cs.shape = rect
	_floor.add_child(cs)
	tree.root.add_child(_floor)
	_e = MAID_SCENE.instantiate()
	_e.lane_floor_y = STREET
	tree.root.add_child(_e)
	_e.set_process(false)
	_e.attack_timer.stop()


func teardown() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	_e.free()
	_floor.free()


func _drop_onto_floor_at(floor_top: float) -> void:
	_floor.global_position = Vector2(0, floor_top + 10.0)
	_e.global_position = Vector2(0, floor_top - _e.foot_offset() - 2.0)
	var tree := Engine.get_main_loop() as SceneTree
	for i in 20:
		await tree.physics_frame


func test_maid_on_road_height_floor_rederives_road_lane() -> String:
	await _drop_onto_floor_at(37.0)
	var r: String = _T.assert_eq(_e.lane, 3, "maid with soles 65px under the street is on lane 3")
	if r != "":
		return r
	r = _T.assert_float_eq(_e.lane_floor_y, STREET, 0.01, "street baseline must not follow her down")
	if r != "":
		return r
	return _T.assert_float_eq(_e.global_position.y, _e.lane_stand_y(3), 0.5, "snapped onto lane 3's floor")


func test_maid_on_street_stays_ground_lane() -> String:
	await _drop_onto_floor_at(STREET)
	var r: String = _T.assert_eq(_e.lane, Lanes.GROUND_LANE, "street floor is the ground lane")
	if r != "":
		return r
	return _T.assert_float_eq(_e.lane_floor_y, STREET, 1.0, "baseline stays on the street")


func test_lane_locked_maid_never_rederives() -> String:
	_e.lane_locked = true
	await _drop_onto_floor_at(37.0)
	return _T.assert_eq(_e.lane, Lanes.GROUND_LANE, "platform/window maids stay lane-locked")
