extends RefCounted

## Arcade cabinet: the pause menu and its Controls screen must be fully drivable by
## joystick/d-pad + buttons from ANY pad. Encoders often enumerate as several pads
## (player 2's side is device 1+), so every default pad binding must be device -1.
## Events go through Input.parse_input_event, the same path real hardware takes, and
## focus is read back from the viewport.

var _T

const TMP := "user://test_joypad_nav_settings.cfg"
const VBOX := "CenterContainer/Panel/Margin/VBoxContainer/"
const PAD := 1  # not pad 0: player-2 side of an encoder

var _menu: Node
var _remap
var _saved_volume: float
var _saved_crt: bool


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func setup() -> void:
	InputRemap.reset_to_defaults()
	_menu = _tree().root.get_node("PauseMenu")
	_remap = _menu.get_node("CenterContainer/RemapPanel")
	_remap.settings_path = TMP
	_saved_volume = _n("VolumeRow/VolumeSlider").value
	_saved_crt = _n("CRTRow/CRTCheckBox").button_pressed
	await _frames(2)


func teardown() -> void:
	if _remap.is_listening():
		_remap.cancel_listen()
	if _remap.visible:
		_remap._on_back()  # the menu vetoes pause while the panel is up
	if _tree().paused:
		_menu.toggle_pause()
	# Writes back through the menu's own save path, so the real settings file ends
	# exactly where it started.
	_n("VolumeRow/VolumeSlider").value = _saved_volume
	_n("CRTRow/CRTCheckBox").button_pressed = _saved_crt
	_remap.settings_path = InputRemap.SETTINGS_PATH
	InputRemap.reset_to_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	await _frames(2)


func _n(path: String) -> Control:
	return _menu.get_node(VBOX + path)


func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


func _focus() -> Control:
	return _menu.get_viewport().gui_get_focus_owner()


func _btn(idx: int, pressed: bool, device := PAD) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = idx
	e.pressed = pressed
	e.pressure = 1.0 if pressed else 0.0
	return e


func _axis(axis: int, val: float, device := PAD) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = axis
	e.axis_value = val
	return e


## Press, hold a frame, release - like a thumb on a real button.
func _tap(idx: int, device := PAD) -> void:
	Input.parse_input_event(_btn(idx, true, device))
	await _frames(2)
	Input.parse_input_event(_btn(idx, false, device))
	await _frames(2)


## Push the stick fully and let it spring back to centre through small values.
func _flick(axis: int, dir: float) -> void:
	for v in [dir, dir * 0.3, 0.0]:
		Input.parse_input_event(_axis(axis, v))
		await _frames(1)
	await _frames(1)


func _open_menu() -> void:
	await _tap(JOY_BUTTON_START)  # project's "pause" pad button (6)


func _name(c: Control) -> String:
	return str(c.name) if c else "<none>"


# --- InputMap: every pad binding answers any device -------------------------------

func test_every_default_pad_binding_matches_any_device() -> String:
	var fails := []
	for action in InputRemap.ACTIONS:
		for e in InputMap.action_get_events(action):
			if not (e is InputEventJoypadButton or e is InputEventJoypadMotion):
				continue
			for device in [0, 1, 3]:
				var probe: InputEvent = e.duplicate()
				probe.device = device
				if probe is InputEventJoypadButton:
					probe.pressed = true
				if not InputMap.event_is_action(probe, action, true):
					fails.append("%s %s dev %d" % [action, InputRemap.event_label(e), device])
	return _T.assert_eq(fails, [], "pad bindings that ignore other pads")


func test_second_pad_dpad_and_stick_drive_ui_actions() -> String:
	var cases := {
		"ui_up": [_btn(JOY_BUTTON_DPAD_UP, true, 3), _axis(JOY_AXIS_LEFT_Y, -1.0, 3)],
		"ui_down": [_btn(JOY_BUTTON_DPAD_DOWN, true, 3), _axis(JOY_AXIS_LEFT_Y, 1.0, 3)],
		"ui_left": [_btn(JOY_BUTTON_DPAD_LEFT, true, 3), _axis(JOY_AXIS_LEFT_X, -1.0, 3)],
		"ui_right": [_btn(JOY_BUTTON_DPAD_RIGHT, true, 3), _axis(JOY_AXIS_LEFT_X, 1.0, 3)],
		"ui_accept": [_btn(JOY_BUTTON_A, true, 3)],
		"Attack": [_btn(JOY_BUTTON_X, true, 3)],
		"Crouch": [_btn(JOY_BUTTON_B, true, 3)],
		"pause": [_btn(JOY_BUTTON_START, true, 3)],
	}
	var fails := []
	for action in cases:
		for e in cases[action]:
			if not InputMap.event_is_action(e, action, true):
				fails.append("%s <- %s" % [action, e.as_text()])
	return _T.assert_eq(fails, [], "device-3 events not matching")


# --- Pause menu ------------------------------------------------------------------

func test_pad_opens_menu_with_slider_focused() -> String:
	await _open_menu()
	var r: String = _T.assert_true(_tree().paused and _menu.visible, "pad 1 Back pauses")
	if r != "":
		return r
	return _T.assert_eq(_name(_focus()), "VolumeSlider", "initial focus")


func test_dpad_left_right_changes_volume() -> String:
	await _open_menu()
	var slider := _n("VolumeRow/VolumeSlider") as HSlider
	slider.value = 0.5
	await _tap(JOY_BUTTON_DPAD_LEFT)
	var after_left := slider.value
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	var r: String = _T.assert_true(after_left < 0.5, "d-pad left lowers volume (%s)" % after_left)
	if r != "":
		return r
	r = _T.assert_true(slider.value > 0.5, "d-pad right raises volume (%s)" % slider.value)
	if r != "":
		return r
	return _T.assert_eq(_name(_focus()), "VolumeSlider", "left/right stay on slider")


func test_dpad_walks_every_control_and_wraps() -> String:
	await _open_menu()
	var down := []
	for i in 5:
		await _tap(JOY_BUTTON_DPAD_DOWN)
		down.append(_name(_focus()))
	var r: String = _T.assert_eq(down,
		["CRTCheckBox", "ControlsButton", "ResumeButton", "ExitButton", "VolumeSlider"],
		"d-pad down cycle")
	if r != "":
		return r
	var up := []
	for i in 5:
		await _tap(JOY_BUTTON_DPAD_UP)
		up.append(_name(_focus()))
	return _T.assert_eq(up,
		["ExitButton", "ResumeButton", "ControlsButton", "CRTCheckBox", "VolumeSlider"],
		"d-pad up cycle")


func test_stick_navigates_menu() -> String:
	await _open_menu()
	await _flick(JOY_AXIS_LEFT_Y, 1.0)
	var r: String = _T.assert_eq(_name(_focus()), "CRTCheckBox", "stick down")
	if r != "":
		return r
	await _flick(JOY_AXIS_LEFT_Y, -1.0)
	return _T.assert_eq(_name(_focus()), "VolumeSlider", "stick up")


func test_a_toggles_crt() -> String:
	await _open_menu()
	await _tap(JOY_BUTTON_DPAD_DOWN)
	var box := _n("CRTRow/CRTCheckBox") as CheckBox
	var before := box.button_pressed
	await _tap(JOY_BUTTON_A)
	return _T.assert_eq(box.button_pressed, not before, "A toggles CRT")


func test_a_on_exit_button_resumes() -> String:
	await _open_menu()
	await _tap(JOY_BUTTON_DPAD_UP)
	await _tap(JOY_BUTTON_A)
	return _T.assert_false(_tree().paused, "header X resumes")


func test_a_on_resume_resumes() -> String:
	await _open_menu()
	for i in 3:
		await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_A)
	return _T.assert_false(_tree().paused, "RESUME resumes")


func test_every_menu_control_shows_focus() -> String:
	var fails := []
	for path in ["HeaderRow/ExitButton", "VolumeRow/VolumeSlider", "CRTRow/CRTCheckBox",
			"ControlsButton", "ResumeButton"]:
		var c := _n(path)
		var box := c.get_theme_stylebox("focus")
		if box == null or box is StyleBoxEmpty:
			fails.append(path)
	return _T.assert_eq(fails, [], "controls with an invisible focus")


# --- Controls (remap) screen ------------------------------------------------------

func _open_remap() -> void:
	await _open_menu()
	for i in 2:
		await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_A)


func test_a_on_controls_opens_remap_on_first_row() -> String:
	await _open_remap()
	var r: String = _T.assert_true(_remap.visible, "remap panel visible")
	if r != "":
		return r
	return _T.assert_true(_focus() == _remap.first_focus(), "first Set focused")


func test_dpad_reaches_every_row_then_bottom_and_back() -> String:
	await _open_remap()
	var actions: Array = InputRemap.ACTIONS.keys()
	for i in range(1, actions.size()):
		await _tap(JOY_BUTTON_DPAD_DOWN)
		if _focus() != _remap._rows[actions[i]]["set"]:
			return "down #%d landed on %s, wanted %s Set" % [i, _name(_focus()), actions[i]]
		var scroll: ScrollContainer = _focus().get_parent().get_parent()
		var vis := Rect2(Vector2.ZERO, scroll.size)
		var rect := Rect2(_focus().global_position - scroll.global_position, _focus().size)
		if not vis.encloses(rect):
			return "row %s Set not scrolled into view" % actions[i]
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	if _focus() != _remap._rows[actions[-1]]["add"]:
		return "right from last Set landed on %s" % _name(_focus())
	await _tap(JOY_BUTTON_DPAD_DOWN)
	if _focus() not in [_remap._reset_button, _remap._back_button]:
		return "down from last row landed on %s" % _name(_focus())
	var bottom := _focus()
	var other: Button = _remap._back_button if bottom == _remap._reset_button else _remap._reset_button
	await _tap(JOY_BUTTON_DPAD_RIGHT if bottom == _remap._reset_button else JOY_BUTTON_DPAD_LEFT)
	if _focus() != other:
		return "left/right between Reset and Back landed on %s" % _name(_focus())
	await _tap(JOY_BUTTON_DPAD_UP)
	var last: Dictionary = _remap._rows[actions[-1]]
	return _T.assert_true(_focus() in [last["set"], last["add"]],
		"up from bottom returns to last row (got %s)" % _name(_focus()))


func test_stick_navigates_rows_and_never_binds_on_return() -> String:
	await _open_remap()
	await _flick(JOY_AXIS_LEFT_Y, 1.0)
	var actions: Array = InputRemap.ACTIONS.keys()
	var row: Dictionary = _remap._rows[actions[1]]
	var r: String = _T.assert_true(_focus() == row["set"], "stick down to row 2 (got %s)" % _name(_focus()))
	if r != "":
		return r
	var before := InputRemap.bindings(actions[1]).map(InputRemap.event_label)
	await _tap(JOY_BUTTON_A)
	r = _T.assert_true(_remap.is_listening(), "A on Set starts listening")
	if r != "":
		return r
	# A resting / drifting stick is never a bind.
	Input.parse_input_event(_axis(JOY_AXIS_LEFT_Y, 0.2))
	Input.parse_input_event(_axis(JOY_AXIS_LEFT_Y, 0.0))
	await _frames(2)
	r = _T.assert_true(_remap.is_listening(), "centred stick did not bind")
	if r != "":
		return r
	return _T.assert_eq(InputRemap.bindings(actions[1]).map(InputRemap.event_label), before,
		"bindings untouched")


func test_listen_binds_button_from_second_pad() -> String:
	await _open_remap()
	await _tap(JOY_BUTTON_A)  # Set on row 1 (Up)
	await _tap(JOY_BUTTON_RIGHT_SHOULDER, 1)
	var labels: Array = InputRemap.bindings("ui_up").map(InputRemap.event_label)
	var r: String = _T.assert_eq(labels, ["Pad Btn 10"], "pad 1 shoulder bound to Up")
	if r != "":
		return r
	var probe := _btn(JOY_BUTTON_RIGHT_SHOULDER, true, 0)
	return _T.assert_true(InputMap.event_is_action(probe, "ui_up", true),
		"binding made on pad 1 works on pad 0")


func test_b_backs_out_of_remap_but_binds_while_listening() -> String:
	await _open_remap()
	await _tap(JOY_BUTTON_A)  # listen on Up
	await _tap(JOY_BUTTON_B)
	var r: String = _T.assert_true(_remap.visible, "B while listening binds, does not close")
	if r != "":
		return r
	r = _T.assert_eq(InputRemap.bindings("ui_up").map(InputRemap.event_label), ["Pad Btn 1"],
		"B captured as a bind")
	if r != "":
		return r
	InputRemap.reset_to_defaults()
	await _tap(JOY_BUTTON_B)
	r = _T.assert_false(_remap.visible, "B closes the remap panel")
	if r != "":
		return r
	return _T.assert_true(_tree().paused and _name(_focus()) == "ControlsButton",
		"back on the pause menu, Controls focused, still paused")
