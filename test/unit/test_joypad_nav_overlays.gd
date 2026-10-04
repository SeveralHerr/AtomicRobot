extends RefCounted

# Arcade cabinet: joystick + buttons only, no mouse, no keyboard. The end card
# (scripts/ui/end_card.gd) is the only interactive screen during play: RESTART beside
# EXIT GAME. A pad player must land on RESTART with focus already there, see that it is
# selected, stay on the card when nudging the stick, and press A to go.
#
# The real levels are loaded (each carries UI/EndCard) and the card is shown the way
# the game shows it: by emitting Globals.player_death / boss_death. ScoreSystem is not
# running here (the level is not current_scene), so no initials are asked for.
# RESTART's own handler changes scene, so the tests swap it for a flag.

var _T

const BOSS_ROOM := "res://scenes/boss_room.tscn"
const MAIN := "res://scenes/main.tscn"
const CARD := "UI/EndCard"

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


func _card() -> EndCard:
	return _level.get_node(CARD) as EndCard


## The end signal, then the wait for the card: a death plays the DeathBeat first.
func _end_run(signal_name: String) -> void:
	Globals.emit_signal(signal_name)
	while _card().beat.running:
		await _frames(1)
	await _frames()


func _swap_handler() -> void:
	_card().restart_game = func() -> void: _activated = true


# --- shown with focus ------------------------------------------------------------

func _focus_after(signal_name: String, scene: String = BOSS_ROOM) -> String:
	await _load(scene)
	await _end_run(signal_name)
	var button := _card().restart_button
	var r: String = _T.assert_true(button.is_visible_in_tree(), "%s overlay is visible" % signal_name)
	if r != "":
		return r
	return _T.assert_true(button.has_focus(),
		"RESTART owns focus once the %s overlay shows (owner: %s)" % [signal_name, _tree().root.gui_get_focus_owner()])


func test_game_over_restart_has_focus_when_shown() -> String:
	return await _focus_after("player_death")


func test_game_over_restart_has_focus_on_street_level() -> String:
	return await _focus_after("player_death", MAIN)


func test_win_restart_has_focus_when_shown() -> String:
	return await _focus_after("boss_death")


# --- d-pad / stick cannot wander off the only control ----------------------------

## Focus may move between the overlay's own buttons, never off them.
func _stays_put(signal_name: String) -> String:
	await _load(BOSS_ROOM)
	await _end_run(signal_name)
	var buttons := [_card().restart_button, _card().exit_button]
	for b in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		await _tap_button(b)
		if not _tree().root.gui_get_focus_owner() in buttons:
			return "d-pad %d moved focus off the overlay to %s" % [b, _tree().root.gui_get_focus_owner()]
	for a in [[JOY_AXIS_LEFT_X, -1.0], [JOY_AXIS_LEFT_X, 1.0], [JOY_AXIS_LEFT_Y, -1.0], [JOY_AXIS_LEFT_Y, 1.0]]:
		await _tap_axis(a[0], a[1])
		if not _tree().root.gui_get_focus_owner() in buttons:
			return "stick %s moved focus off the overlay to %s" % [a, _tree().root.gui_get_focus_owner()]
	return ""


func test_game_over_dpad_and_stick_keep_focus_on_overlay() -> String:
	return await _stays_put("player_death")


func test_win_dpad_and_stick_keep_focus_on_card() -> String:
	return await _stays_put("boss_death")


# --- EXIT GAME -------------------------------------------------------------------

func test_game_over_dpad_right_reaches_exit_and_a_quits() -> String:
	for scene in [MAIN, BOSS_ROOM]:
		await _load(scene)
		var card := _card()
		var quits := [0]
		card.quit_game = func() -> void: quits[0] += 1
		await _end_run("player_death")
		var exit := card.exit_button
		var r: String = _T.assert_true(exit.is_visible_in_tree(), "%s: EXIT GAME shows on Game Over" % scene)
		if r != "":
			return r
		await _tap_button(JOY_BUTTON_DPAD_RIGHT)
		r = _T.assert_true(exit.has_focus(), "%s: d-pad right reaches EXIT GAME" % scene)
		if r != "":
			return r
		await _tap_button(JOY_BUTTON_A)
		r = _T.assert_eq(quits[0], 1, "%s: A on EXIT GAME quits" % scene)
		if r != "":
			return r
		_level.queue_free()
		_level = null
		await _frames()
	return ""


# --- A activates ---------------------------------------------------------------

func _accept(signal_name: String, device: int) -> String:
	await _load(BOSS_ROOM)
	_swap_handler()
	Globals.emit_signal(signal_name)
	# Mashing A through the death beat and the card's arm delay must not restart.
	await _tap_button(JOY_BUTTON_A, device)
	while _card().beat.running:
		await _tap_button(JOY_BUTTON_A, device)
	await _tap_button(JOY_BUTTON_A, device)
	if _activated:
		return "pad A pressed RESTART inside the beat or the %.1fs mash guard after %s" % [EndCard.ARM_DELAY, signal_name]
	await _tree().create_timer(EndCard.ARM_DELAY + 0.1).timeout
	await _tap_button(JOY_BUTTON_A, device)
	return _T.assert_true(_activated, "pad A (device %d) presses RESTART after %s" % [device, signal_name])


func test_game_over_pad_a_presses_restart() -> String:
	return await _accept("player_death", 0)


func test_win_pad_a_presses_restart() -> String:
	return await _accept("boss_death", 0)


## Second encoder pad (project.godot binds pad events to device -1 = any pad).
func test_game_over_second_pad_a_presses_restart() -> String:
	return await _accept("player_death", 1)


# --- visible selection -----------------------------------------------------------

func test_restart_buttons_draw_a_visible_focus_box() -> String:
	await _load(BOSS_ROOM)
	for b in [_card().restart_button, _card().exit_button]:
		var box: StyleBox = b.get_theme_stylebox("focus")
		if box == null or box is StyleBoxEmpty:
			return "%s has no visible focus stylebox - arcade players cannot see it is selected" % b.name
		if b.focus_mode == Control.FOCUS_NONE:
			return "%s cannot take focus" % b.name
	return ""


# --- no keyboard-only continue -------------------------------------------------

func test_interact_has_a_pad_binding() -> String:
	for e in InputMap.action_get_events("Interact"):
		if e is InputEventJoypadButton:
			return ""
	return "Interact (mailbox / crack prompts) has no joypad binding"
