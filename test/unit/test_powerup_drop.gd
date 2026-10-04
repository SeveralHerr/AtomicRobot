extends RefCounted

## Utils.drop_powerup: kills land inside a hit's physics callback, so the pickup (an
## Area2D) must join the scene deferred — added on the spot it errored "Can't change
## this state while flushing queries" (seen in a seeded mortal autoplay run).

var _T

const MAID := preload("res://scenes/meter_maid_melee.tscn")

var _stage: Node2D
var _old_scene: Node


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func setup() -> void:
	_stage = Node2D.new()
	_tree().root.add_child(_stage)
	_old_scene = _tree().current_scene
	_tree().current_scene = _stage


func teardown() -> void:
	_tree().current_scene = _old_scene
	_stage.queue_free()
	await _tree().process_frame


func test_pickup_joins_the_scene_deferred_where_the_enemy_fell() -> String:
	var maid: Node2D = MAID.instantiate()
	_stage.add_child(maid)
	maid.process_mode = Node.PROCESS_MODE_DISABLED
	maid.global_position = Vector2(321, -20)
	var pickup: Node2D = Utils.drop_powerup(maid, "rage")
	var r: String = _T.assert_true(pickup != null, "a known id drops a pickup")
	if r == "":
		r = _T.assert_false(pickup.is_inside_tree(), "not added mid-callback")
	if r != "":
		return r
	await _tree().process_frame
	r = _T.assert_true(pickup.is_inside_tree() and pickup.get_parent() == _stage, "joins the current scene next frame")
	if r == "":
		r = _T.assert_float_eq(pickup.global_position.x, 321.0, 0.01, "dropped where the enemy fell")
	if r == "":
		r = _T.assert_true(pickup.global_position.y < maid.global_position.y + maid.foot_offset(), "hovers above the floor line")
	return r
