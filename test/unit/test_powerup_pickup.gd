extends RefCounted

## PowerupPickup lifetimes: a DROPPED pickup blinks then despawns (PowerupRules
## PICKUP_LIFETIME / PICKUP_BLINK_LEAD); a level-PLACED one is a permanent reward
## for reaching it and must never blink or despawn.

var _T

const PICKUP := preload("res://scenes/powerup_pickup.tscn")

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


func _spawn(placed: bool) -> Node2D:
	var p: Node2D = PICKUP.instantiate()
	p.set("placed", placed)
	_stage.add_child(p)
	p.set_process(false)  # stepped by hand below
	return p


# --- dropped (characterization) ---------------------------------------------

func test_dropped_pickup_despawns_after_its_lifetime() -> String:
	var p := _spawn(false)
	p._process(PowerupRules.PICKUP_LIFETIME + 0.1)
	return _T.assert_true(p.is_queued_for_deletion(), "dropped pickup despawns")


func test_dropped_pickup_survives_until_its_lifetime() -> String:
	var p := _spawn(false)
	p._process(PowerupRules.PICKUP_LIFETIME - 0.5)
	return _T.assert_false(p.is_queued_for_deletion(), "still there before the lifetime ends")


func test_dropped_pickup_blinks_inside_the_lead() -> String:
	var p := _spawn(false)
	var seen_hidden := false
	p._process(PowerupRules.PICKUP_LIFETIME - PowerupRules.PICKUP_BLINK_LEAD + 0.01)
	for i in 60:
		p._process(0.02)
		if not p.sprite.visible:
			seen_hidden = true
	return _T.assert_true(seen_hidden, "blinks while about to expire")


# --- placed (static) --------------------------------------------------------

func test_placed_pickup_never_despawns() -> String:
	var p := _spawn(true)
	for i in 10:
		p._process(PowerupRules.PICKUP_LIFETIME)
	return _T.assert_false(p.is_queued_for_deletion(), "placed pickup is permanent")


func test_placed_pickup_never_blinks() -> String:
	var p := _spawn(true)
	for i in 400:
		p._process(0.05)
		if not p.sprite.visible:
			return "placed pickup blinked at step %d" % i
	return ""


func test_placed_pickup_keeps_its_authored_parent() -> String:
	# A lanes scene: drops reparent into Lanes.sort_layer there.
	_stage.scene_file_path = Lanes.LANE_SCENE_PREFIX + "pickup_stage.tscn"
	var p := _spawn(true)
	await _tree().process_frame
	await _tree().process_frame
	return _T.assert_true(p.get_parent() == _stage, "stays under the level node it was placed in")


func test_placed_pickup_has_a_glow() -> String:
	var p := _spawn(true)
	return _T.assert_true(p.get_node_or_null("Glow") != null, "placed pickups get a glow halo")


func test_dropped_pickup_has_no_glow() -> String:
	var p := _spawn(false)
	return _T.assert_true(p.get_node_or_null("Glow") == null, "drops stay plain")


func test_placed_pickup_is_on_the_ground_lane() -> String:
	# Platforms and scaffolds are ground-lane floors (Player._update_lane_floor).
	var p := _spawn(true)
	return _T.assert_eq(p.lane, Lanes.GROUND_LANE, "placed pickups sit on ground-lane geometry")


func test_dropped_pickup_joins_the_lane_sort_layer() -> String:
	_stage.scene_file_path = Lanes.LANE_SCENE_PREFIX + "pickup_stage.tscn"
	var p := _spawn(false)
	await _tree().process_frame
	await _tree().process_frame
	return _T.assert_eq(String(p.get_parent().name), Lanes.SORT_LAYER_NAME, "drops sort with the lane bodies")


func test_placed_glow_draws_behind_the_sprite() -> String:
	var p := _spawn(true)
	await _tree().process_frame
	var glow := p.get_node("Glow")
	return _T.assert_true(glow.get_index() < p.sprite.get_index(), "glow is drawn before (under) the pickup sprite")
