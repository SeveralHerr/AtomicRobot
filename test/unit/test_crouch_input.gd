extends RefCounted

# Crouch has its own button. S / Down used to double up — tap stepped a lane toward
# the camera, a 0.25s hold crouched — so every lane step waited for the key to come
# back up and every crouch started with a lane-step decision. Now ui_down is a pure
# lane step on its press edge and the `Crouch` action (C / pad B) owns crouching.
#
# The real Player scene is driven with a thin subclass: lanes need main.tscn and a
# captured walkway line to be live, which is not what these tests are about, so
# try_change_lane only records the request and is_grounded always holds.

var _T

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const FRAME := 1.0 / 60.0
const ACTIONS := ["ui_down", "Crouch"]


class InputPlayer:
	extends Player
	var lane_requests: Array[int] = []

	func try_change_lane(dir: int) -> bool:
		lane_requests.append(dir)
		return true

	func is_grounded() -> bool:
		return true


var _p: InputPlayer


func setup() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node := PLAYER_SCENE.instantiate()
	node.set_script(InputPlayer)
	_p = node
	tree.root.add_child(_p)
	# Frames are stepped by hand below so each test controls exactly what runs.
	_p.set_process(false)
	_p.set_physics_process(false)


func teardown() -> void:
	for a in ACTIONS:
		Input.action_release(a)
	# CrouchState.exit_state defers a shape swap; let it land before the player goes.
	await (Engine.get_main_loop() as SceneTree).process_frame
	_p.free()
	_p = null


func _frame() -> void:
	_p.state_machine.update(FRAME)
	_p._process_lane_input()


func _state() -> State:
	return _p.state_machine.current_state


func test_project_binds_crouch_to_c_and_pad_b() -> String:
	if not InputMap.has_action("Crouch"):
		return "no Crouch action in the InputMap"
	var has_c := false
	var has_pad := false
	for e in InputMap.action_get_events("Crouch"):
		if e is InputEventKey and e.physical_keycode == KEY_C:
			has_c = true
		if e is InputEventJoypadButton and e.button_index == JOY_BUTTON_B:
			has_pad = true
	var r: String = _T.assert_true(has_c, "Crouch is bound to physical C")
	if r != "":
		return r
	return _T.assert_true(has_pad, "Crouch is bound to joypad button 1")


func test_down_steps_a_lane_on_the_press_frame() -> String:
	Input.action_press("ui_down")
	_frame()
	return _T.assert_eq(_p.lane_requests, [1] as Array[int], "lane step fires on press, not release")


func test_holding_down_never_crouches() -> String:
	Input.action_press("ui_down")
	for i in 60:
		_frame()
	var r: String = _T.assert_false(_state() is CrouchState, "a 1s hold of S stays standing")
	if r != "":
		return r
	return _T.assert_eq(_p.lane_requests, [1] as Array[int], "one press is one lane step")


func test_crouch_action_enters_crouch_state() -> String:
	Input.action_press("Crouch")
	_frame()
	var r: String = _T.assert_true(_state() is CrouchState, "Crouch crouches on the press frame")
	if r != "":
		return r
	return _T.assert_eq(_p.lane_requests.size(), 0, "crouching never steps a lane")


## CrouchState must read Crouch itself: if it still polled ui_down it would stand the
## player up every frame and only the lane-input re-crouch would hide it.
func test_crouch_state_holds_while_crouch_is_held() -> String:
	Input.action_press("Crouch")
	_frame()
	for i in 30:
		_p.state_machine.update(FRAME)
	return _T.assert_true(_state() is CrouchState, "held Crouch keeps CrouchState on its own")


func test_releasing_crouch_stands_up() -> String:
	Input.action_press("Crouch")
	_frame()
	Input.action_release("Crouch")
	_frame()
	return _T.assert_true(_state() is IdleState, "releasing Crouch returns to idle")


## Crouch is polled while held, not edge-triggered: held through a jump, it should
## crouch on touchdown instead of making the player re-press it.
func test_crouch_held_through_a_landing_crouches_on_touchdown() -> String:
	_p.state_machine.change_state("FallState")
	Input.action_press("Crouch")
	_p._process_lane_input()
	var r: String = _T.assert_true(_state() is FallState, "no crouching mid-air")
	if r != "":
		return r
	_p.state_machine.change_state("IdleState")
	_p._process_lane_input()
	return _T.assert_true(_state() is CrouchState, "still-held Crouch crouches on landing")
