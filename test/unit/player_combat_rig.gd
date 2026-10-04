extends RefCounted

## Shared fixture for the player-combat tests (test_air_attack.gd, test_attack_chain.gd):
## the real Player scene on a real floor, stepped with real physics frames. Attack and
## jump are injected as InputEventActions (State.handle_input only sees events);
## left/right are held with Input.action_press (the states poll them).
## Everything spawned lives under one world node so teardown leaves root clean.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MAID_SCENE := preload("res://scenes/meter_maid.tscn")
const FLOOR_Y := 420.0
const HP := 50
const HELD := ["ui_left", "ui_right", "Run", "Attack", "ui_accept"]

var world: Node2D
var p: Player
var _char_before: String
## State class names seen each physics frame by step() — lets a test prove a swing
## chained straight into the next one without passing through Idle.
var trail: Array[String] = []
## The player's standing Y on the floor (captured before any lift).
var ground_y := 0.0


func _init() -> void:
	_char_before = Globals.selected_character


func free_all() -> void:
	for a in HELD:
		Input.action_release(a)
	if is_instance_valid(world):
		world.free()
	world = null
	p = null
	Globals.selected_character = _char_before


func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func add(n: Node) -> Node:
	if not is_instance_valid(world):
		world = Node2D.new()
		tree().root.add_child(world)
	world.add_child(n)
	return n


## Real physics frames; records the player's state name each frame in `trail`.
func step(n: int = 1) -> void:
	for i in n:
		await tree().physics_frame
		if is_instance_valid(p):
			trail.append(state_name())


func state_name() -> String:
	var st = p.state_machine.current_state
	for k in p.state_machine.states:
		if p.state_machine.states[k] == st:
			return k
	return "?"


## Spawns `character` standing on a flat floor (or `height` px above standing).
func spawn(character: String, height: float = 0.0) -> void:
	Globals.selected_character = character
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	cs.shape = rect
	floor_body.add_child(cs)
	add(floor_body)
	floor_body.global_position = Vector2(400, FLOOR_Y)
	p = add(PLAYER_SCENE.instantiate())
	p.global_position = Vector2(400, 340)
	await step(20)  # land and settle into Idle
	ground_y = p.global_position.y
	if height > 0.0:
		p.global_position.y -= height
		p.velocity = Vector2.ZERO
		p.state_machine.change_state("FallState")
		await step(1)
	trail.clear()


func maid(dx: float) -> Enemy:
	var e: Enemy = add(MAID_SCENE.instantiate())
	e.set_physics_process(false)
	e.set_process(false)
	e.health = HP
	e.lane = p.current_lane
	e.global_position = Vector2(p.global_position.x + dx, ground_y)
	return e


func event(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## Press-and-release on one frame, like a quick tap.
func tap(action: String) -> void:
	event(action, true)
	event(action, false)


## Steps until `cond` holds (or `limit` frames pass); returns the frames taken, -1 on timeout.
func until(cond: Callable, limit: int = 120) -> int:
	for i in limit:
		if cond.call():
			return i
		await step(1)
	return -1
