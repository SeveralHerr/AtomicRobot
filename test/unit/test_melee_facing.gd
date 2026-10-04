extends RefCounted

# A melee swing hits what the player FACES, never a maid standing behind them, and
# never one on another lane. Real Player + meter maid scenes on a real floor, real
# physics frames, real input: walk with Input.action_press, swing with an injected
# InputEventAction (state handle_input only sees events, not polled actions).

var _T

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MAID_SCENE := preload("res://scenes/meter_maid.tscn")
## AttackState fires a projectile for these; everyone else swings a fist.
const RANGED := ["Robot", "Cass"]
const GAP := 40.0  # maid centre to player centre; the fist reaches 16..80px ahead
const HP := 50

# Everything (and whatever it spawns as a sibling: sparks, popups, shots) lives
# under one world node, so teardown leaves the root exactly as it found it.
var _world: Node2D
var _char_before: String
var _p: Player


func setup() -> void:
	_char_before = Globals.selected_character


func teardown() -> void:
	for a in ["ui_left", "ui_right", "Attack"]:
		Input.action_release(a)
	if is_instance_valid(_world):
		_world.free()
	_world = null
	_p = null
	Globals.selected_character = _char_before


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _add(n: Node) -> Node:
	if not is_instance_valid(_world):
		_world = Node2D.new()
		_tree().root.add_child(_world)
	_world.add_child(n)
	return n


func _physics(n: int) -> void:
	for i in n:
		await _tree().physics_frame


func _spawn(character: String) -> void:
	Globals.selected_character = character
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	cs.shape = rect
	floor_body.add_child(cs)
	_add(floor_body)
	floor_body.global_position = Vector2(400, 420)
	_p = _add(PLAYER_SCENE.instantiate())
	_p.global_position = Vector2(400, 340)
	await _physics(20)  # land and settle into Idle


func _maid(dx: float, lane: int) -> Enemy:
	var e: Enemy = _add(MAID_SCENE.instantiate())
	e.set_physics_process(false)
	e.set_process(false)
	e.health = HP
	e.lane = lane
	e.global_position = _p.global_position + Vector2(dx, 0)
	return e


func _walk(action: String, frames: int = 8) -> void:
	Input.action_press(action)
	await _physics(frames)
	Input.action_release(action)
	await _physics(4)


func _swing() -> void:
	var ev := InputEventAction.new()
	ev.action = "Attack"
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await _physics(1)
	ev = InputEventAction.new()
	ev.action = "Attack"
	ev.pressed = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	# Whole Attack anim: hit frame plus the return to Idle.
	for i in 120:
		await _physics(1)
		if not (_p.state_machine.current_state is AttackState) and i > 5:
			break


## Face `facing` (+1 right / -1 left) by walking, then swing once with a maid in
## front and one behind on the player's lane. Returns "" or a failure message.
func _front_hits_back_misses(character: String, turns: Array) -> String:
	await _spawn(character)
	for t in turns:
		await _walk("ui_left" if t < 0 else "ui_right")
	var facing: int = turns[-1] if turns.size() > 0 else 1
	var lane := _p.current_lane
	var front := _maid(GAP * facing, lane)
	var back := _maid(-GAP * facing, lane)
	await _physics(2)
	await _swing()
	var ctx := "%s facing %s after %s" % [character, facing, turns]
	var r: String = _T.assert_true(front.health < HP, ctx + ": maid in front is hit")
	if r != "":
		return r
	return _T.assert_eq(back.health, HP, ctx + ": maid BEHIND is not hit")


func test_swing_facing_right_misses_maid_behind() -> String:
	return await _front_hits_back_misses("Ryan", [1])


func test_swing_facing_left_misses_maid_behind() -> String:
	return await _front_hits_back_misses("Ryan", [-1])


func test_swing_after_left_right_left_misses_maid_behind() -> String:
	return await _front_hits_back_misses("Ryan", [-1, 1, -1])


func test_swing_after_right_left_right_misses_maid_behind() -> String:
	return await _front_hits_back_misses("Ryan", [1, -1, 1])


func _melee_characters() -> Array:
	return Globals.character_dict.keys().filter(func(c): return not c in RANGED)


func test_every_melee_character_lands_front_hit_both_ways() -> String:
	var chars := _melee_characters()
	var r0: String = _T.assert_gte(chars.size(), 4, "melee roster derived from character_dict")
	if r0 != "":
		return r0
	for c in chars:
		for turns in [[1], [-1]]:
			var r: String = await _front_hits_back_misses(c, turns)
			if r != "":
				return r
			teardown()
	return ""


func test_swing_misses_maid_in_front_on_another_lane() -> String:
	await _spawn("Ryan")
	var other := _maid(GAP, _p.current_lane + 1)
	var same := _maid(GAP, _p.current_lane)
	await _physics(2)
	await _swing()
	var r: String = _T.assert_true(same.health < HP, "same-lane maid in front is hit")
	if r != "":
		return r
	return _T.assert_eq(other.health, HP, "maid on another lane is not hit")


func test_swing_misses_maid_hugging_the_players_back() -> String:
	# Maids pass through the player (enemy layer is not in its mask), so one can stand
	# with its body overlapping the player's from behind. Still behind: no hit.
	await _spawn("Ryan")
	await _walk("ui_left")
	var back := _maid(10.0, _p.current_lane)
	await _physics(2)
	await _swing()
	return _T.assert_eq(back.health, HP, "maid overlapping the player's back is not hit")


func test_ranged_shot_flies_the_way_the_player_faces() -> String:
	for c in RANGED:
		for facing in [1, -1]:
			await _spawn(c)
			await _walk("ui_left" if facing < 0 else "ui_right")
			# Read the shot's dir as it leaves the tree too: a fast shot (Cass's flip-flop)
			# can fly its full range and free itself before the swing animation ends.
			var dirs: Array[int] = []
			var on_add := func(n: Node) -> void:
				if n is LaneProjectile:
					n.tree_exiting.connect(func() -> void: dirs.append(int(sign(n.dir))))
			_p.get_tree().node_added.connect(on_add)
			var before := _p.get_parent().get_child_count()
			await _swing()
			_p.get_tree().node_added.disconnect(on_add)
			for n in _p.get_parent().get_children().slice(before):
				if n is LaneProjectile:
					dirs.append(int(sign(n.dir)))
			var ctx := "%s facing %s" % [c, facing]
			var r: String = _T.assert_true(not dirs.is_empty(), ctx + ": a projectile spawned")
			if r != "":
				return r
			r = _T.assert_eq(dirs[0], facing, ctx + ": projectile dir")
			if r != "":
				return r
			teardown()
	return ""
