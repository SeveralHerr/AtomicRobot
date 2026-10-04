extends RefCounted

# Arcade cabinet: joystick/d-pad + buttons only. Every front-end screen (title,
# story, controls splash; character select lives in test_character_select.gd) must advance or navigate from a pad.
# Real scenes are loaded; scene-changing methods are stubbed via thin subclasses so
# a test never boots main.tscn.

var _T

const START := preload("res://scenes/startscreen.tscn")
const STORY := preload("res://scenes/story.tscn")
const CONTROLS := preload("res://scenes/controls_splash.tscn")

const PAD_A := 0
const PAD_UP := 11
const PAD_DOWN := 12
const PAD_LEFT := 13
const PAD_RIGHT := 14


class StubStart:
	extends "res://scripts/startscreen.gd"
	var advanced := 0
	func _advance() -> void:
		advanced += 1


class StubStory:
	extends "res://scripts/story.gd"
	var advanced := 0
	func transition_to_game() -> void:
		advanced += 1


class StubControls:
	extends "res://scripts/controls_splash.gd"
	var advanced := 0
	func _start_transition() -> void:
		advanced += 1


var _scene: Node
var _saved_character: String


func setup() -> void:
	_saved_character = Globals.selected_character


func teardown() -> void:
	Globals.selected_character = _saved_character
	if is_instance_valid(_scene):
		_scene.free()
	_scene = null
	# A real slot press changes scene; drop whatever it loaded.
	var tree := _tree()
	if tree.current_scene:
		var cur := tree.current_scene
		tree.current_scene = null
		cur.free()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n := 2) -> void:
	for i in n:
		await _tree().process_frame


func _mount(packed: PackedScene, stub: Script = null) -> Node:
	_scene = packed.instantiate()
	if stub:
		_scene.set_script(stub)
	_tree().root.add_child(_scene)
	await _frames()
	return _scene


func _pad(button: int, device := 0) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = device
	e.pressed = true
	Input.parse_input_event(e)
	await _frames()
	var up := e.duplicate() as InputEventJoypadButton
	up.pressed = false
	Input.parse_input_event(up)
	await _frames()


func _stick(axis: int, value: float, device := 0) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = device
	Input.parse_input_event(e)
	await _frames()
	var rest := e.duplicate() as InputEventJoypadMotion
	rest.axis_value = 0.0
	Input.parse_input_event(rest)
	await _frames()


# --- Title screen ------------------------------------------------------------

func test_startscreen_ignores_pad_before_delay() -> String:
	var s: Node = await _mount(START, StubStart)
	await _pad(PAD_A)
	return _T.assert_eq(s.advanced, 0, "no advance before the anti-skip delay")


func test_startscreen_advances_on_pad_button() -> String:
	var s: Node = await _mount(START, StubStart)
	s.delay = true
	await _pad(PAD_A)
	return _T.assert_eq(s.advanced, 1, "'Press any button' accepts joypad A")


func test_startscreen_advances_on_second_pad() -> String:
	var s: Node = await _mount(START, StubStart)
	s.delay = true
	await _pad(3, 1)
	return _T.assert_eq(s.advanced, 1, "any button on pad 2 also counts")


func test_startscreen_stick_wiggle_does_not_advance() -> String:
	var s: Node = await _mount(START, StubStart)
	s.delay = true
	await _stick(JOY_AXIS_LEFT_X, 1.0)
	return _T.assert_eq(s.advanced, 0, "stick motion is not a button press")


func test_startscreen_timer_arms_delay() -> String:
	var s: Node = await _mount(START, StubStart)
	await _tree().create_timer(s.get_node("Timer").wait_time + 0.2).timeout
	return _T.assert_true(s.delay, "Timer arms the screen without input")


# --- Story ---------------------------------------------------------------------

func test_story_advances_on_pad_after_text_shows() -> String:
	var s: Node = await _mount(STORY, StubStory)
	await _pad(PAD_A)
	var r: String = _T.assert_eq(s.advanced, 0, "pad ignored while text fades in")
	if r != "":
		return r
	var waited := 0.0
	while not s.can_proceed and waited < 4.0:
		await _tree().create_timer(0.1).timeout
		waited += 0.1
	r = _T.assert_true(s.can_proceed, "story finishes fading in within 4s")
	if r != "":
		return r
	await _pad(PAD_A)
	return _T.assert_eq(s.advanced, 1, "joypad A advances past the story")


# --- Controls splash -----------------------------------------------------------

func test_controls_splash_advances_on_pad_button() -> String:
	var s: Node = await _mount(CONTROLS, StubControls)
	await _pad(PAD_A)
	var r: String = _T.assert_eq(s.advanced, 0, "no advance before the delay")
	if r != "":
		return r
	s.delay = true
	await _pad(PAD_A)
	return _T.assert_eq(s.advanced, 1, "joypad A starts the game")
