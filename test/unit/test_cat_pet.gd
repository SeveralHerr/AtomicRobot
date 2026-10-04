extends RefCounted

# Pet the cat (scripts/cat.gd): stand by the rooftop cat on its level and press
# Interact. It stops, squashes happily, puffs a few hearts and walks on; it can be
# petted again after a short cooldown. The real Player scene supplies the "player"
# group member; its physics is off so it stays where the test puts it.

var _T

const CAT_SCENE := preload("res://scenes/cat.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const LEDGE_X := 500.0
const LEDGE_Y := 300.0
const LEDGE_W := 400.0

var _world: Node2D
var _player: Node2D


func setup() -> void:
	_world = Node2D.new()
	_tree().root.add_child(_world)
	var body := StaticBody2D.new()
	body.collision_layer = 32
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LEDGE_W, 6)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(LEDGE_X, LEDGE_Y + 3)
	_world.add_child(body)
	_player = PLAYER_SCENE.instantiate()
	_world.add_child(_player)
	_player.set_process(false)
	_player.set_physics_process(false)
	_player.global_position = Vector2(-5000, -5000)


func teardown() -> void:
	Input.action_release("Interact")
	_world.free()
	_world = null


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


func _cat() -> Cat:
	var cat: Cat = CAT_SCENE.instantiate()
	cat.pop_out = false
	cat.direction = 1
	cat.speed = 60.0
	cat.min_walk_time = 999.0
	cat.max_walk_time = 999.0
	cat.pet_time = 0.3
	cat.pet_cooldown = 0.3
	cat.position = Vector2(LEDGE_X, LEDGE_Y)
	_world.add_child(cat)
	return cat


## Puts the player's FEET at the cat's feet + offset.
func _stand(offset: Vector2, cat: Cat) -> void:
	_player.global_position = cat.global_position + offset - Vector2(0, _player.foot_offset())


## One Interact tap at frame start, seen by the cat's _process.
func _press_interact() -> void:
	await _frames(1)
	Input.action_press("Interact")
	await _frames(1)
	Input.action_release("Interact")
	await _frames(1)


func _hearts(cat: Cat) -> int:
	return cat.get_tree().get_nodes_in_group(Cat.HEART_GROUP).size()


func test_interact_beside_cat_pets_it() -> String:
	var cat := _cat()
	_stand(Vector2(20, 0), cat)
	await _press_interact()
	return _T.assert_eq(cat.mode, Cat.Mode.PET, "Interact next to the cat pets it")


func test_interact_far_from_cat_does_nothing() -> String:
	var cat := _cat()
	_stand(Vector2(Cat.PET_REACH_X + 30, 0), cat)
	await _press_interact()
	return _T.assert_eq(cat.mode, Cat.Mode.WALK, "out of reach: keeps walking")


func test_player_on_another_level_cannot_pet() -> String:
	var cat := _cat()
	_stand(Vector2(0, Cat.PET_REACH_Y + 30), cat)  # street below the roof
	await _press_interact()
	return _T.assert_eq(cat.mode, Cat.Mode.WALK, "below the roof: no pet")


func test_reach_edges() -> String:
	var at := Vector2(100, 100)
	var r: String = _T.assert_true(Cat.in_pet_reach(at, at + Vector2(Cat.PET_REACH_X - 1, 0)), "just inside x")
	if r != "":
		return r
	r = _T.assert_true(Cat.in_pet_reach(at, at - Vector2(Cat.PET_REACH_X - 1, 0)), "just inside x, left side")
	if r != "":
		return r
	r = _T.assert_false(Cat.in_pet_reach(at, at + Vector2(Cat.PET_REACH_X + 1, 0)), "just outside x")
	if r != "":
		return r
	r = _T.assert_false(Cat.in_pet_reach(at, at - Vector2(Cat.PET_REACH_X + 1, 0)), "just outside x, left side")
	if r != "":
		return r
	r = _T.assert_true(Cat.in_pet_reach(at, at + Vector2(0, Cat.PET_REACH_Y - 1)), "just inside y")
	if r != "":
		return r
	r = _T.assert_false(Cat.in_pet_reach(at, at - Vector2(0, Cat.PET_REACH_Y + 1)), "just above y")
	if r != "":
		return r
	return _T.assert_false(Cat.in_pet_reach(at, at + Vector2(0, Cat.PET_REACH_Y + 1)), "just below y")


## Reach is measured from the player's SOLES (foot_offset ~20px below its origin):
## measured from the origin, a player a step above the cat's floor would miss.
func test_reach_uses_player_feet_not_origin() -> String:
	var cat := _cat()
	_stand(Vector2(20, -12), cat)
	await _press_interact()
	return _T.assert_eq(cat.mode, Cat.Mode.PET, "feet 12px up (origin ~32px up) still pets")


func test_petted_cat_stands_still_and_puffs_hearts() -> String:
	var cat := _cat()
	_stand(Vector2(20, 0), cat)
	await _press_interact()
	var x := cat.position.x
	await _frames(5)
	var r: String = _T.assert_float_eq(cat.position.x, x, 0.01, "stops walking while petted")
	if r != "":
		return r
	var n := _hearts(cat)
	return _T.assert_true(n >= 2 and n <= 4, "2-4 hearts rise (got %d)" % n)


func test_petted_cat_turns_to_the_player() -> String:
	var cat := _cat()  # walking right
	_stand(Vector2(-20, 0), cat)
	await _press_interact()
	return _T.assert_true(cat.sprite.flip_h, "faces the player on its left")


func test_cat_walks_on_after_pet() -> String:
	var cat := _cat()
	_stand(Vector2(20, 0), cat)
	await _press_interact()
	await _tree().create_timer(cat.pet_time + 0.1).timeout
	var r: String = _T.assert_eq(cat.mode, Cat.Mode.WALK, "resumes walking")
	if r != "":
		return r
	return _T.assert_eq(cat.sprite.animation, &"walk", "walk animation back on")


func test_cooldown_blocks_an_instant_repet() -> String:
	var cat := _cat()
	cat.pet_cooldown = 5.0
	_stand(Vector2(20, 0), cat)
	await _press_interact()
	await _tree().create_timer(cat.pet_time + 0.1).timeout
	_stand(Vector2(20, 0), cat)
	await _press_interact()
	return _T.assert_eq(cat.mode, Cat.Mode.WALK, "cooling down: no second pet yet")


func test_can_pet_again_after_cooldown() -> String:
	var cat := _cat()
	_stand(Vector2(20, 0), cat)
	await _press_interact()
	await _tree().create_timer(cat.pet_time + cat.pet_cooldown + 0.15).timeout
	_stand(Vector2(20, 0), cat)
	await _press_interact()
	return _T.assert_eq(cat.mode, Cat.Mode.PET, "re-pettable after the cooldown")


func test_prompt_shows_only_when_pettable() -> String:
	var cat := _cat()
	await _frames(2)
	var r: String = _T.assert_false(cat.pet_label.visible, "hidden while the player is away")
	if r != "":
		return r
	_stand(Vector2(20, 0), cat)
	await _frames(2)
	r = _T.assert_true(cat.pet_label.visible, "shown beside the cat")
	if r != "":
		return r
	await _press_interact()
	return _T.assert_false(cat.pet_label.visible, "hidden while being petted")


func test_cat_mid_hop_cannot_be_petted() -> String:
	var cat: Cat = CAT_SCENE.instantiate()
	cat.position = Vector2(LEDGE_X, LEDGE_Y - 25)
	_world.add_child(cat)
	_stand(Vector2.ZERO, cat)
	await _frames(1)
	Input.action_press("Interact")
	await _frames(1)
	var r: String = _T.assert_eq(cat.mode, Cat.Mode.POP, "still hopping out of the wall")
	if r != "":
		return r
	return _T.assert_false(cat.pet_label.visible, "no prompt mid-hop")


func test_cat_strolls_away_from_the_petter() -> String:
	var cat := _cat()  # walking right, into the player
	_stand(Vector2(20, 0), cat)
	await _press_interact()
	await _tree().create_timer(cat.pet_time + 0.1).timeout
	return _T.assert_eq(cat.direction, -1, "walks off away from the player on its right")


func test_sitting_cat_can_be_petted_and_gets_up_after() -> String:
	var cat := _cat()
	cat._sit()
	cat._timer = 999.0
	_stand(Vector2(-20, 0), cat)
	await _press_interact()
	var r: String = _T.assert_eq(cat.mode, Cat.Mode.PET, "a sitting cat takes a pet")
	if r != "":
		return r
	await _tree().create_timer(cat.pet_time + 0.1).timeout
	return _T.assert_eq(cat.mode, Cat.Mode.WALK, "and walks off after, not back to a 999s sit")


## A walking cat used to stroll out of reach while the player stopped beside it
## (validation round 10: the press missed by 3px). It now waits while pettable.
func test_walking_cat_waits_while_player_is_beside_it() -> String:
	var cat := _cat()
	_stand(Vector2(20, 0), cat)
	await _tree().physics_frame
	var x := cat.position.x
	for i in 10:
		await _tree().physics_frame
	var r: String = _T.assert_float_eq(cat.position.x, x, 0.01, "holds still beside the player")
	if r != "":
		return r
	_stand(Vector2(Cat.PET_REACH_X + 40, 0), cat)
	for i in 5:
		await _tree().physics_frame
	return _T.assert_gt(cat.position.x, x + 0.5, "walks on once the player leaves")


## The prompt goes the same frame the pet starts (no one-frame flash over the hearts).
func test_prompt_hides_on_the_press_frame() -> String:
	var cat := _cat()
	_stand(Vector2(20, 0), cat)
	await _frames(2)
	Input.action_press("Interact")
	await _frames(1)
	var r: String = _T.assert_eq(cat.mode, Cat.Mode.PET, "petted this frame")
	if r != "":
		return r
	return _T.assert_false(cat.pet_label.visible, "prompt already hidden")


## The user picked the newspaper stand's prompt (reads better through the CRT): the
## cat must wear the stand's own LabelSettings, not a look-alike, in the stand's
## "[word]" format, but the word is PET ("Cat should say 'pet' and not interact").
func test_prompt_is_the_newspaper_stands_prompt() -> String:
	var cat := _cat()
	var stand: Node = load("res://scenes/interactive_mailbox.tscn").instantiate()
	var src := stand.get_node("InteractLabel") as Label
	var want_settings := src.label_settings
	var stand_text := src.text
	stand.free()
	var r: String = _T.assert_eq(cat.pet_label.label_settings, want_settings, "same LabelSettings resource")
	if r != "":
		return r
	r = _T.assert_eq(cat.pet_label.text, "[pet]", "says pet, in the stand's bracket format")
	if r != "":
		return r
	r = _T.assert_true(stand_text.begins_with("[") and stand_text.ends_with("]"), "stand still uses [word]")
	if r != "":
		return r
	return _T.assert_false("interact" in cat.pet_label.text.to_lower(), "never says interact")


## Same placement as the stand: the prompt box top sits as high above the floor as
## the stand's does above its feet, so it clears the player's cap the same way.
func test_prompt_sits_at_the_stands_height_above_the_floor() -> String:
	var cat := _cat()
	var l := cat.pet_label
	var r: String = _T.assert_float_eq(l.position.y, -InteractPrompt.rise(), 0.5, "box top at the stand's rise")
	if r != "":
		return r
	return _T.assert_float_eq(l.position.x + l.size.x / 2.0, 0.0, 0.5, "centred over the cat")


## rise() is measured off the stand's scene (art bottom to label top), pinned here so a
## regression in the measurement shows: newspaperstand.png is 48 tall, art to its
## bottom row, label top authored at -39.
func test_rise_is_measured_off_the_newspaper_stand() -> String:
	return _T.assert_float_eq(InteractPrompt.rise(), 63.0, 0.5, "24 (art bottom) + 39 (label top)")
