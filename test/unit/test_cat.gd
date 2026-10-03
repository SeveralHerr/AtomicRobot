extends RefCounted

# Rooftop cat easter egg: breaking the skyscraper crack (crack.gd, releases_cat)
# lets one decorative cat out, which strolls its ledge and turns back at the edge
# instead of walking off. Physics frames are real, so cats are sped up to keep
# each walk test well under a second.

var _T

const CRACK_SCENE := preload("res://scenes/crack.tscn")
const CAT_SCENE := preload("res://scenes/cat.tscn")
const LEDGE_X := 500.0
const LEDGE_Y := 300.0  # top surface of the fake ledge
const LEDGE_W := 60.0

var _nodes: Array[Node] = []


func teardown() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _add(n: Node) -> Node:
	_tree().root.add_child(n)
	_nodes.append(n)
	return n


## A one-way platform like scenes/platform.tscn: layer 6 (Platforms), 60 wide.
func _ledge() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 32
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LEDGE_W, 6)
	shape.shape = rect
	shape.one_way_collision = true
	body.add_child(shape)
	body.position = Vector2(LEDGE_X, LEDGE_Y + 3)
	_add(body)


func _walking_cat(x: float, dir: int) -> Cat:
	var cat: Cat = CAT_SCENE.instantiate()
	cat.pop_out = false
	cat.direction = dir
	cat.speed = 150.0
	cat.min_walk_time = 999.0
	cat.max_walk_time = 999.0
	cat.position = Vector2(x, LEDGE_Y)
	return _add(cat)


func _cats_under(n: Node) -> int:
	return n.find_children("*", "Cat", true, false).size()


func _break(crack: Crack) -> void:
	for i in 8:  # more hits than frames: re-hitting an open crack must not add cats
		crack.receive_hit()


func test_breaking_crack_spawns_exactly_one_cat() -> String:
	var crack: Crack = CRACK_SCENE.instantiate()
	crack.releases_cat = true
	_add(crack)
	_break(crack)
	await _tree().process_frame
	return _T.assert_eq(_cats_under(crack), 1, "one cat after breaking the crack open")


func test_crack_without_cat_flag_stays_empty() -> String:
	var crack: Crack = CRACK_SCENE.instantiate()
	_add(crack)
	_break(crack)
	await _tree().process_frame
	return _T.assert_eq(_cats_under(crack), 0, "only the flagged rooftop crack hides a cat")


func test_partly_cracked_wall_keeps_cat_inside() -> String:
	var crack: Crack = CRACK_SCENE.instantiate()
	crack.releases_cat = true
	_add(crack)
	for i in 4:
		crack.receive_hit()
	await _tree().process_frame
	return _T.assert_eq(_cats_under(crack), 0, "4 of 5 hits: still closed")


func test_cat_walks_and_faces_its_heading() -> String:
	_ledge()
	var cat := _walking_cat(LEDGE_X + 10, -1)
	await _tree().physics_frame
	var start := cat.position.x
	for i in 5:
		await _tree().physics_frame
	var msg: String = _T.assert_gt(start - cat.position.x, 1.0, "walks left")
	if msg != "":
		return msg
	msg = _T.assert_eq(cat.sprite.animation, &"walk", "plays walk while moving")
	if msg != "":
		return msg
	return _T.assert_true(cat.sprite.flip_h, "flipped to face left (sheet faces right)")


func test_cat_turns_back_at_ledge_edge() -> String:
	_ledge()
	var cat := _walking_cat(LEDGE_X, 1)
	var right_edge := LEDGE_X + LEDGE_W / 2.0
	var max_x := cat.position.x
	var turned := false
	for i in 90:
		await _tree().physics_frame
		max_x = maxf(max_x, cat.position.x)
		if cat.direction < 0:
			turned = true
	var msg: String = _T.assert_true(turned, "turned around")
	if msg != "":
		return msg
	msg = _T.assert_true(max_x <= right_edge, "never stepped past the edge (max %.1f, edge %.1f)" % [max_x, right_edge])
	if msg != "":
		return msg
	return _T.assert_true(cat.position.x >= LEDGE_X - LEDGE_W / 2.0, "still on the ledge (x %.1f)" % cat.position.x)


func _pop_and_settle(crack_y: float) -> Cat:
	var cat: Cat = CAT_SCENE.instantiate()
	cat.position = Vector2(LEDGE_X, crack_y)
	_add(cat)
	var t := 0
	while cat.mode == Cat.Mode.POP and t < 120:
		await _tree().physics_frame
		t += 1
	return cat


func test_popped_cat_lands_on_floor_below_crack() -> String:
	_ledge()
	var cat := await _pop_and_settle(LEDGE_Y - 25)  # crack in the wall above the ledge
	return _T.assert_float_eq(cat.global_position.y, LEDGE_Y, 1.0, "feet on the ledge top")


func test_popped_cat_leaps_up_onto_roof_above_crack() -> String:
	# The window-building crack sits ~110px under its roof (top of the fire escape).
	_ledge()
	var cat := await _pop_and_settle(LEDGE_Y + 110)
	return _T.assert_float_eq(cat.global_position.y, LEDGE_Y, 1.0, "climbed onto the roof")
