extends RefCounted

# The initials entry section of the end card (scripts/ui/initials_entry.gd), driven
# the three ways players drive it: arcade pad (d-pad, stick, A/B), keyboard (typing)
# and touch. The card around it is covered by test_end_card.gd.

var _T

const BOSS_ROOM := "res://scenes/boss_room.tscn"
const MAIN := "res://scenes/main.tscn"
const TEST_SAVE := "user://test_scores_card.cfg"

var _nodes: Array[Node] = []
var _saved_path: String


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func _add(node: Node) -> Node:
	_tree().root.add_child(node)
	_nodes.append(node)
	return node


func setup() -> void:
	_saved_path = ScoreSystem.save_path
	ScoreSystem.save_path = TEST_SAVE
	ScoreSystem.clear_records()


func teardown() -> void:
	for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		Input.action_release(a)
	var f := _tree().root.gui_get_focus_owner()
	if f:
		f.release_focus()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	ScoreSystem.begin_stage("")
	ScoreSystem.running = false
	ScoreSystem.clear_records()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	ScoreSystem.save_path = _saved_path
	ScoreSystem.reload()
	await _frames()


## A bare InitialsEntry in a plain host, open on AAA.
func _entry(start: String = "AAA") -> InitialsEntry:
	var host := _add(Control.new())
	var e := InitialsEntry.new()
	host.add_child(e)
	e.open(start)
	return e


func _armed_entry(start: String = "AAA") -> InitialsEntry:
	var e := _entry(start)
	await _tree().create_timer(InitialsEntry.ARM_DELAY + 0.05).timeout
	return e


## Inputs are injected at the top of a frame, before _process, the way real input is
## flushed. Injected straight after a timer callback they would land AFTER this
## frame's _process and be released before the next one ever polled them.
func _pad(index: JoyButton) -> void:
	await _frames(1)
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = index
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await _frames(1)


func _key(code: Key, unicode: int = 0) -> void:
	await _frames(1)
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = unicode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await _frames(1)


func _type(text: String) -> void:
	for c in text:
		await _key(OS.find_keycode_from_string(c), c.to_lower().unicode_at(0))


# --- Initials: arcade pad ------------------------------------------------------

func test_opens_prefilled_on_first_letter() -> String:
	var e := _entry("KAT")
	var r: String = _T.assert_eq(e.initials(), "KAT", "starts on the last initials used")
	if r != "":
		return r
	return _T.assert_eq(e.cursor, 0, "cursor on first letter")


func test_mash_guard_ignores_input_on_open() -> String:
	var e := _entry()
	var sent: Array = []
	e.submitted.connect(func(s: String) -> void: sent.append(s))
	for i in 5:
		await _pad(JOY_BUTTON_A)
	await _key(KEY_Z, "z".unicode_at(0))
	await _pad(JOY_BUTTON_B)
	var r: String = _T.assert_eq(e.cursor, 0, "jump-mash did not advance")
	if r != "":
		return r
	r = _T.assert_eq(e.initials(), "AAA", "keys typed while arming are ignored")
	if r != "":
		return r
	return _T.assert_eq(sent.size(), 0, "jump-mash did not submit")


## Pinball's cursor: three letters then OK. JUMP on a letter moves on; JUMP on OK saves.
func test_dpad_dials_moves_and_a_saves_on_ok() -> String:
	var e: InitialsEntry = await _armed_entry()
	var sent: Array = []
	e.submitted.connect(func(s: String) -> void: sent.append(s))
	await _pad(JOY_BUTTON_DPAD_UP)            # A -> B
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_DPAD_DOWN)          # A -> wraps to Z
	await _pad(JOY_BUTTON_A)                  # -> third letter
	await _pad(JOY_BUTTON_DPAD_UP)
	await _pad(JOY_BUTTON_DPAD_UP)            # C
	await _pad(JOY_BUTTON_B)                  # back to second
	var r: String = _T.assert_eq(e.cursor, 1, "B steps back")
	if r != "":
		return r
	await _pad(JOY_BUTTON_A)
	await _pad(JOY_BUTTON_A)                  # -> OK
	r = _T.assert_eq(e.cursor, InitialsEntry.OK_SLOT, "A walks onto OK")
	if r != "":
		return r
	await _pad(JOY_BUTTON_DPAD_UP)            # dialling on OK does nothing
	await _pad(JOY_BUTTON_A)                  # save
	r = _T.assert_eq(sent, ["BZC"], "submitted dialled initials")
	if r != "":
		return r
	await _pad(JOY_BUTTON_A)
	return _T.assert_eq(sent.size(), 1, "extra A after OK does not resubmit")


func test_right_reaches_ok_and_stops() -> String:
	var e: InitialsEntry = await _armed_entry()
	for i in 6:
		await _pad(JOY_BUTTON_DPAD_RIGHT)
	return _T.assert_eq(e.cursor, InitialsEntry.OK_SLOT, "OK is the last stop")


## A keyboard tap or a d-pad flick can press AND release between two frames; the
## poll must still see one step.
func test_tap_inside_one_frame_still_counts() -> String:
	var e: InitialsEntry = await _armed_entry()
	await _frames(1)
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = JOY_BUTTON_DPAD_UP
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await _frames(2)
	return _T.assert_eq(e.letters[0], "B", "same-frame tap dialled once")


## Analogue stick: one push is ONE step however many motion events it sends, and
## holding it auto-repeats.
func test_stick_push_is_one_step_and_hold_repeats() -> String:
	var e: InitialsEntry = await _armed_entry()
	for v in [0.6, 0.8, 1.0, 1.0, 0.9]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = JOY_AXIS_LEFT_Y
		ev.axis_value = -v
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await _frames(1)
	var r: String = _T.assert_eq(e.letters[0], "B", "one push, one letter")
	if r != "":
		return r
	await _tree().create_timer(InitialsEntry.REPEAT_DELAY + InitialsEntry.REPEAT_RATE * 4).timeout
	var ev0 := InputEventJoypadMotion.new()
	ev0.axis = JOY_AXIS_LEFT_Y
	ev0.axis_value = 0.0
	Input.parse_input_event(ev0)
	Input.flush_buffered_events()
	await _frames(1)
	return _T.assert_gt(HighScoreTable.ALPHABET.find(e.letters[0]), 2, "held stick repeats past C")


## Walk-away player: the letters showing are saved so the cabinet is not left stuck.
func test_idle_entry_saves_itself() -> String:
	var e: InitialsEntry = await _armed_entry("ZED")
	var sent: Array = []
	e.submitted.connect(func(s: String) -> void: sent.append(s))
	e.idle = InitialsEntry.IDLE_SAVE_SECONDS - 0.05
	await _tree().create_timer(0.2).timeout
	return _T.assert_eq(sent, ["ZED"], "idle timeout saved the letters showing")


func test_input_resets_the_idle_clock() -> String:
	var e: InitialsEntry = await _armed_entry()
	e.idle = InitialsEntry.IDLE_SAVE_SECONDS - 1.0
	await _pad(JOY_BUTTON_DPAD_UP)
	var r: String = _T.assert_true(e.idle < 1.0, "a stick press restarts the idle clock (idle=%.2f)" % e.idle)
	if r != "":
		return r
	e.idle = InitialsEntry.IDLE_SAVE_SECONDS - 1.0
	await _key(KEY_K, "k".unicode_at(0))
	return _T.assert_true(e.idle < 1.0, "a typed letter restarts the idle clock (idle=%.2f)" % e.idle)


# --- Initials: keyboard --------------------------------------------------------

## W/A/S/D are also ui_up/left/down/right: typing them must enter the letter, not
## move the cursor or spin the wheel. Three letters land the cursor on OK.
func test_typing_wasd_enters_letters_then_enter_saves() -> String:
	var e: InitialsEntry = await _armed_entry()
	var sent: Array = []
	e.submitted.connect(func(s: String) -> void: sent.append(s))
	await _type("WAS")
	var r: String = _T.assert_eq(e.initials(), "WAS", "typed letters land as typed")
	if r != "":
		return r
	r = _T.assert_eq(e.cursor, InitialsEntry.OK_SLOT, "third letter moves onto OK")
	if r != "":
		return r
	await _key(KEY_BACKSPACE)
	await _type("D")
	r = _T.assert_eq(e.initials(), "WAD", "backspace steps back, typing overwrites")
	if r != "":
		return r
	await _key(KEY_ENTER)
	return _T.assert_eq(sent, ["WAD"], "Enter on OK saves")


func test_typing_ignores_symbols_and_digits() -> String:
	var e: InitialsEntry = await _armed_entry()
	await _key(KEY_SEMICOLON, ";".unicode_at(0))
	await _key(KEY_7, "7".unicode_at(0))
	return _T.assert_eq(e.initials(), "AAA", "only A-Z are initials")


# --- Initials: touch -----------------------------------------------------------

func _all_arrows(e: InitialsEntry) -> Array:
	return e.find_children("*", "ArrowButton", true, false)


func test_touch_targets_are_big_enough() -> String:
	var e := _entry()
	await _frames()
	var buttons: Array = _all_arrows(e)
	var r: String = _T.assert_eq(buttons.size(), HighScoreTable.INITIALS_LENGTH * 2, "up+down per letter")
	if r != "":
		return r
	buttons.append(e._ok)
	buttons.append_array(e._slots)
	for b in buttons:
		if b.size.x < ComicStyle.TOUCH.x or b.size.y < ComicStyle.TOUCH.y:
			return "%s is %s - too small to tap on a phone" % [b, b.size]
	return ""


func test_touch_arrows_and_ok_submit() -> String:
	var e: InitialsEntry = await _armed_entry()
	var sent: Array = []
	e.submitted.connect(func(s: String) -> void: sent.append(s))
	e._arrows[1][0].pressed.emit()     # second letter up: B
	e._arrows[1][0].pressed.emit()     # C
	e._arrows[2][1].pressed.emit()     # third letter down: Z
	e._slots[0].pressed.emit()
	var r: String = _T.assert_eq(e.cursor, 0, "tapping a letter selects it")
	if r != "":
		return r
	e._ok.pressed.emit()
	e._ok.pressed.emit()
	return _T.assert_eq(sent, ["ACZ"], "touch-entered initials, submitted once")


## OK is disabled for the mash guard too (a mobile jump-mash can land on it).
func test_touch_ok_respects_mash_guard() -> String:
	var e := _entry()
	var sent: Array = []
	e.submitted.connect(func(s: String) -> void: sent.append(s))
	e._ok.pressed.emit()
	var r: String = _T.assert_true(e._ok.disabled, "OK disabled while arming")
	if r != "":
		return r
	return _T.assert_eq(sent.size(), 0, "no early submit")


func test_hint_text_matches_input() -> String:
	var r: String = _T.assert_true("TAP" in InitialsEntry.hint_text(true), "touch hint")
	if r != "":
		return r
	return _T.assert_true("UP / DOWN" in InitialsEntry.hint_text(false), "stick hint")
