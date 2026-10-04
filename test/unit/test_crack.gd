extends RefCounted

# Secret wall (scripts/crack.gd): five blows open the hidden crack, the wall's
# collision goes, and Interact claims one orb, once.

var _T

const CRACK_SCENE := preload("res://scenes/crack.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _nodes: Array[Node] = []


func teardown() -> void:
	Input.action_release("Interact")
	await _tree().process_frame
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


func _player() -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	_add(p)
	p.set_process(false)
	p.set_physics_process(false)
	p.health = Player.HITS_PER_ORB
	return p


func _crack() -> Crack:
	return _add(CRACK_SCENE.instantiate())


## Real seconds: the orb flies to the HUD (tweened) before it heals, and headless
## frames run much faster than real time.
func _settle(seconds: float = 1.2) -> void:
	await _tree().create_timer(seconds).timeout


func _press_interact() -> void:
	Input.action_press("Interact")
	await _tree().process_frame
	Input.action_release("Interact")
	await _tree().process_frame


func test_crack_is_hidden_until_first_hit() -> String:
	var c := _crack()
	var r: String = _T.assert_false(c.visible, "secret wall starts hidden")
	if r != "":
		return r
	c.receive_hit()
	return _T.assert_true(c.visible, "first blow reveals the crack")


func test_four_hits_keep_the_wall_solid() -> String:
	var c := _crack()
	for i in 4:
		c.receive_hit()
	var r: String = _T.assert_eq(c.animated_sprite_2d.frame, 4, "one frame per hit")
	if r != "":
		return r
	return _T.assert_false(c.interact_label.visible, "no prompt before it opens")


func test_fifth_hit_opens_the_wall() -> String:
	var c := _crack()
	for i in 5:
		c.receive_hit()
	await _tree().process_frame
	var r: String = _T.assert_eq(c.animated_sprite_2d.frame, 5, "open frame")
	if r != "":
		return r
	r = _T.assert_false(is_instance_valid(c.static_body_2d), "wall collision removed")
	if r != "":
		return r
	return _T.assert_true(c.interact_label.visible, "prompt shown on the open wall")


func test_interact_claims_one_orb() -> String:
	var p := _player()
	var c := _crack()
	for i in 5:
		c.receive_hit()
	await _press_interact()
	await _settle()
	return _T.assert_eq(p.health, 2 * Player.HITS_PER_ORB, "one orb claimed")


## Bug: hitting the open wall again re-showed the prompt, and every Interact after
## that paid out another orb.
func test_hitting_a_claimed_wall_pays_out_no_more() -> String:
	var p := _player()
	var c := _crack()
	for i in 5:
		c.receive_hit()
	await _press_interact()
	await _settle()
	c.receive_hit()
	await _press_interact()
	await _settle()
	return _T.assert_eq(p.health, 2 * Player.HITS_PER_ORB, "the wall pays out once")
