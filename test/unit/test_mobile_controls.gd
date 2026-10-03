extends RefCounted

# Headless tests for the touch layout (scenes/mobile_controls.tscn + scripts/mobile_ui.gd).
#
# Two contracts matter here. The first is placement: the virtual joystick owns the left
# side of the screen and every action button sits on the right, so a left thumb steering
# can never land on Attack. The second is multi-touch: action buttons are driven from
# _input() rather than Button.pressed because mouse emulation only tracks one touch
# index, which would silently drop the second thumb while the first holds the joystick.
#
# The runner never processes a frame, so Godot never resolves anchors into rects and
# @onready vars never fire. setup() does both by hand: NOTIFICATION_READY for the script,
# and _layout_rect() to compute what the engine would have produced at viewport size.

var _T
var _ui: Control
# Node name -> the rect the engine would lay that node out at, at viewport size.
var _rects: Dictionary = {}

const SCENE = preload("res://scenes/mobile_controls.tscn")

const ACTION_BUTTONS := ["JumpButton", "AttackButton", "CrouchUI", "InteractButton", "RunButton"]
const JOYSTICK := "Virtual Joystick2"


func setup() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	_ui = SCENE.instantiate()
	tree.root.add_child(_ui)
	_ui.propagate_notification(Node.NOTIFICATION_READY)

	var view := _viewport_size()
	for name in ACTION_BUTTONS + [JOYSTICK]:
		var control: Control = _ui.get_node(name)
		var rect := _layout_rect(control, view)
		_rects[name] = rect
		# Pin the node at the computed rect so the script's own get_global_rect() hit
		# testing agrees with what a real frame would have produced.
		control.set_anchors_preset(Control.PRESET_TOP_LEFT)
		control.position = rect.position
		control.size = rect.size
		# Buttons hide themselves when there's no touchscreen (always true headless).
		control.show()


func teardown() -> void:
	if _ui:
		_ui.get_parent().remove_child(_ui)
		_ui.queue_free()
		_ui = null
	_rects.clear()


func _viewport_size() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)


## What Godot's layout would resolve this control's anchors + offsets to, given a
## parent that fills the viewport (which is how MobileUI is anchored in every scene).
func _layout_rect(control: Control, view: Vector2) -> Rect2:
	var top_left := Vector2(
		control.anchor_left * view.x + control.offset_left,
		control.anchor_top * view.y + control.offset_top
	)
	var bottom_right := Vector2(
		control.anchor_right * view.x + control.offset_right,
		control.anchor_bottom * view.y + control.offset_bottom
	)
	return Rect2(top_left, bottom_right - top_left)


func _touch(index: int, node_name: String, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = (_rects[node_name] as Rect2).get_center()
	_ui._input(event)


func test_joystick_sits_on_the_left_half() -> String:
	var view := _viewport_size()
	var joystick: Rect2 = _rects[JOYSTICK]
	return _T.assert_true(
		joystick.end.x <= view.x * 0.5,
		"joystick should stay in the left half, ends at x=%s of %s" % [joystick.end.x, view.x]
	)


func test_action_buttons_sit_on_the_right_half() -> String:
	var view := _viewport_size()
	for name in ACTION_BUTTONS:
		var rect: Rect2 = _rects[name]
		var err: String = _T.assert_true(
			rect.position.x >= view.x * 0.5,
			"%s should start in the right half, starts at x=%s" % [name, rect.position.x]
		)
		if err != "":
			return err
	return ""


func test_every_control_stays_on_screen() -> String:
	var screen := Rect2(Vector2.ZERO, _viewport_size())
	for name in _rects:
		var rect: Rect2 = _rects[name]
		var err: String = _T.assert_true(
			screen.encloses(rect), "%s at %s falls outside the %s viewport" % [name, rect, screen.size]
		)
		if err != "":
			return err
	return ""


func test_action_buttons_do_not_overlap_the_joystick() -> String:
	var joystick: Rect2 = _rects[JOYSTICK]
	for name in ACTION_BUTTONS:
		var err: String = _T.assert_false(
			joystick.intersects(_rects[name]), "%s overlaps the joystick" % name
		)
		if err != "":
			return err
	return ""


func test_action_buttons_do_not_overlap_each_other() -> String:
	for i in ACTION_BUTTONS.size():
		for j in range(i + 1, ACTION_BUTTONS.size()):
			var err: String = _T.assert_false(
				(_rects[ACTION_BUTTONS[i]] as Rect2).intersects(_rects[ACTION_BUTTONS[j]]),
				"%s overlaps %s" % [ACTION_BUTTONS[i], ACTION_BUTTONS[j]]
			)
			if err != "":
				return err
	return ""


func test_every_action_button_maps_to_a_real_input_action() -> String:
	for name in ACTION_BUTTONS:
		var node := _ui.get_node(name)
		var err: String = _T.assert_true(
			_ui._action_buttons.has(node), "%s has no input action mapped" % name
		)
		if err != "":
			return err
		err = _T.assert_true(
			InputMap.has_action(_ui._action_buttons[node]),
			"%s maps to unknown action '%s'" % [name, _ui._action_buttons[node]]
		)
		if err != "":
			return err
	return ""


func test_crouch_button_drives_the_crouch_action() -> String:
	# S/Down is a lane step now (fed by the joystick); the button must not step lanes.
	return _T.assert_eq(
		_ui._action_buttons[_ui.get_node("CrouchUI")], "Crouch", "CrouchUI should press Crouch"
	)


func test_touch_holds_the_button_until_release() -> String:
	_touch(0, "AttackButton", true)
	var err: String = _T.assert_eq(
		_ui._held.get(0), _ui.get_node("AttackButton"), "attack should be held while touched"
	)
	if err != "":
		return err
	_touch(0, "AttackButton", false)
	return _T.assert_false(_ui._held.has(0), "attack should be released on touch up")


func test_second_finger_works_while_the_first_is_down() -> String:
	_touch(0, "RunButton", true)
	_touch(1, "AttackButton", true)
	var err: String = _T.assert_eq(_ui._held.size(), 2, "both fingers should be tracked")
	if err != "":
		return err
	# Releasing the attack finger must not let go of run.
	_touch(1, "AttackButton", false)
	return _T.assert_eq(
		_ui._held.get(0), _ui.get_node("RunButton"), "run should survive the other finger lifting"
	)


func test_menu_button_hidden_without_touchscreen() -> String:
	# Headless has no touchscreen, same as the Picade cabinet (keyboard/arcade stick).
	return _T.assert_false(
		_ui.get_node("PauseButton").visible, "MENU button should only show on touch devices"
	)


func test_touch_outside_any_button_is_ignored() -> String:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = Vector2(10, 10)
	_ui._input(event)
	return _T.assert_true(_ui._held.is_empty(), "empty screen area should not hold a button")
