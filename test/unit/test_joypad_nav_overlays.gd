extends RefCounted

# Arcade cabinet: joystick + buttons only, no mouse, no keyboard. The in-game end
# screens (Game Over, You Win) are the only interactive overlays during play, and each
# is a single RESTART button. A pad player must land on it with focus already there,
# see that it is selected, stay on it when nudging the stick, and press A to go.
#
# The real boss_room.tscn is loaded (it carries both containers) and the overlays are
# shown the way the game shows them: by emitting Globals.player_death / boss_death.
# RESTART's own handler changes scene, which would tear down the runner's tree, so the
# tests swap it for a flag before pressing A.

var _T

const BOSS_ROOM := "res://scenes/boss_room.tscn"
const MAIN := "res://scenes/main.tscn"
const GAME_OVER_BUTTON := "UI/GameOverContainer/VBoxContainer/Button"
const WIN_BUTTON := "UI/WinContainer/VBoxContainer/Button"

var _level: Node
var _activated := false


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func _load(path: String) -> void:
	_level = (load(path) as PackedScene).instantiate()
	_tree().root.add_child(_level)
	await _frames()


func setup() -> void:
	_activated = false


func teardown() -> void:
	var vp := _tree().root
	var f := vp.gui_get_focus_owner()
	if f:
		f.release_focus()
	if _level:
		_level.queue_free()
		_level = null
	await _frames()


func _tap_button(index: JoyButton, device: int = 0) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = device
		e.button_index = index
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(1)
	Input.flush_buffered_events()


func _tap_axis(axis: JoyAxis, value: float, device: int = 0) -> void:
	for v in [value, 0.0]:
		var e := InputEventJoypadMotion.new()
		e.device = device
		e.axis = axis
		e.axis_value = v
		Input.parse_input_event(e)
		await _frames(1)


func _swap_handler(button: Button) -> void:
	for c in button.pressed.get_connections():
		button.pressed.disconnect(c["callable"])
	button.pressed.connect(func(): _activated = true)


# --- shown with focus ------------------------------------------------------------

func _focus_after(signal_name: String, button_path: String, scene: String = BOSS_ROOM) -> String:
	await _load(scene)
	Globals.emit_signal(signal_name)
	await _frames()
	var button := _level.get_node(button_path) as Button
	var r: String = _T.assert_true(button.is_visible_in_tree(), "%s overlay is visible" % signal_name)
	if r != "":
		return r
	return _T.assert_true(button.has_focus(),
		"RESTART owns focus once the %s overlay shows (owner: %s)" % [signal_name, _tree().root.gui_get_focus_owner()])


func test_game_over_restart_has_focus_when_shown() -> String:
	return await _focus_after("player_death", GAME_OVER_BUTTON)


func test_game_over_restart_has_focus_on_street_level() -> String:
	return await _focus_after("player_death", GAME_OVER_BUTTON, MAIN)


func test_win_restart_has_focus_when_shown() -> String:
	return await _focus_after("boss_death", WIN_BUTTON)


# --- d-pad / stick cannot wander off the only control ----------------------------

func _stays_put(signal_name: String, button_path: String) -> String:
	await _load(BOSS_ROOM)
	Globals.emit_signal(signal_name)
	await _frames()
	var button := _level.get_node(button_path) as Button
	for b in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		await _tap_button(b)
		if not button.has_focus():
			return "d-pad %d moved focus off RESTART to %s" % [b, _tree().root.gui_get_focus_owner()]
	for a in [[JOY_AXIS_LEFT_X, -1.0], [JOY_AXIS_LEFT_X, 1.0], [JOY_AXIS_LEFT_Y, -1.0], [JOY_AXIS_LEFT_Y, 1.0]]:
		await _tap_axis(a[0], a[1])
		if not button.has_focus():
			return "stick %s moved focus off RESTART to %s" % [a, _tree().root.gui_get_focus_owner()]
	return ""


func test_game_over_dpad_and_stick_keep_focus_on_restart() -> String:
	return await _stays_put("player_death", GAME_OVER_BUTTON)


func test_win_dpad_and_stick_keep_focus_on_restart() -> String:
	return await _stays_put("boss_death", WIN_BUTTON)


# --- A activates ---------------------------------------------------------------

func _accept(signal_name: String, button_path: String, device: int) -> String:
	await _load(BOSS_ROOM)
	Globals.emit_signal(signal_name)
	await _frames()
	_swap_handler(_level.get_node(button_path) as Button)
	await _tap_button(JOY_BUTTON_A, device)
	if _activated:
		return "pad A pressed RESTART inside the %.1fs mash guard after %s" % [GameOver.ARM_DELAY, signal_name]
	await _tree().create_timer(GameOver.ARM_DELAY + 0.1).timeout
	await _tap_button(JOY_BUTTON_A, device)
	return _T.assert_true(_activated, "pad A (device %d) presses RESTART after %s" % [device, signal_name])


func test_game_over_pad_a_presses_restart() -> String:
	return await _accept("player_death", GAME_OVER_BUTTON, 0)


func test_win_pad_a_presses_restart() -> String:
	return await _accept("boss_death", WIN_BUTTON, 0)


## Second encoder pad (project.godot binds pad events to device -1 = any pad).
func test_game_over_second_pad_a_presses_restart() -> String:
	return await _accept("player_death", GAME_OVER_BUTTON, 1)


# --- visible selection -----------------------------------------------------------

func test_restart_buttons_draw_a_visible_focus_box() -> String:
	await _load(BOSS_ROOM)
	for path in [GAME_OVER_BUTTON, WIN_BUTTON]:
		var b := _level.get_node(path) as Button
		var box := b.get_theme_stylebox("focus")
		if box == null or box is StyleBoxEmpty:
			return "%s has no visible focus stylebox - arcade players cannot see it is selected" % path
		if b.focus_mode == Control.FOCUS_NONE:
			return "%s cannot take focus" % path
	return ""


# --- no keyboard-only continue -------------------------------------------------

func test_interact_has_a_pad_binding() -> String:
	for e in InputMap.action_get_events("Interact"):
		if e is InputEventJoypadButton:
			return ""
	return "Interact (mailbox / crack prompts) has no joypad binding"
