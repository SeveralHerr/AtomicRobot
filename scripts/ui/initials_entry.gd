class_name InitialsEntry
extends VBoxContainer

## "ENTER YOUR INITIALS", a section of the end card (scripts/ui/end_card.gd). Same
## rules as atomic-pinball's src/ui/initials.js so both cabinet games behave alike:
##   * stick / d-pad: up/down dials A-Z (hold repeats), left/right moves across the
##     three letters AND the OK button; JUMP on a letter = next, on OK = save; B = back
##   * keyboard: type the letters (W/A/S/D type, they do not move), Backspace back,
##     Enter next/save, arrows dial/move
##   * touch: arrow buttons above/below each letter, tap a letter to select it, OK
## Left alone for IDLE_SAVE_SECONDS it saves the letters showing, so a player who walks
## away does not leave the cabinet stuck on this screen.
##
## Directions are POLLED rather than read from events: an analogue stick sends a stream
## of motion events while held and would spin the wheel; polling sees one push.

signal submitted(initials: String)

## Mash guard: JUMP is also "next", and the player is usually still hammering it as
## the run ends.
const ARM_DELAY := 0.6
const REPEAT_DELAY := 0.4
const REPEAT_RATE := 0.15
const BLINK_SECONDS := 0.25
const IDLE_SAVE_SECONDS := 30.0
const DIRECTIONS: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
## Cursor stop for the OK button, after the letters.
const OK_SLOT := HighScoreTable.INITIALS_LENGTH

var letters: Array[String] = []
var cursor: int = 0
var armed: bool = false
var idle: float = 0.0

var _slots: Array[Button] = []
var _underlines: Array[ColorRect] = []
## [up, down] ArrowButtons per letter.
var _arrows: Array = []
var _ok: Button
var _done: bool = false
var _held_dir: String = ""
var _held_time: float = 0.0
var _blink: float = 0.0
## Set when a letter key is typed: A/S/D/W are ALSO ui_left/down/right/up, so the poll
## ignores directions until every direction key is let go.
var _mute_dirs: bool = false
var _box_letter: StyleBoxFlat = ComicStyle.box(ComicStyle.PAPER)
var _box_selected: StyleBoxFlat = ComicStyle.box(ComicStyle.YELLOW, 4)
var _box_ok_selected: StyleBoxFlat = ComicStyle.box(ComicStyle.BLUE, 4)


func _init() -> void:
	add_theme_constant_override("separation", 8)
	visible = false
	_build()


func _build() -> void:
	add_child(ComicStyle.label("ENTER YOUR INITIALS", ComicStyle.LABEL, 38, ComicStyle.PLUM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for i in HighScoreTable.INITIALS_LENGTH:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		var up := ArrowButton.new(true)
		up.pressed.connect(_touch_dial.bind(i, 1))
		col.add_child(up)
		var letter := Button.new()
		letter.custom_minimum_size = Vector2(ComicStyle.TOUCH.x, 112)
		letter.focus_mode = Control.FOCUS_NONE
		letter.add_theme_font_override("font", ComicStyle.DISPLAY)
		letter.add_theme_font_size_override("font_size", 76)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			letter.add_theme_color_override(state, ComicStyle.INK)
		letter.pressed.connect(_select.bind(i))
		col.add_child(letter)
		_slots.append(letter)
		# Pinball's blinking red underline on the selected letter.
		var underline := ColorRect.new()
		underline.color = ComicStyle.RED
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		underline.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		underline.offset_top = -12
		underline.offset_bottom = -6
		underline.offset_left = 10
		underline.offset_right = -10
		letter.add_child(underline)
		_underlines.append(underline)
		var down := ArrowButton.new(false)
		down.pressed.connect(_touch_dial.bind(i, -1))
		col.add_child(down)
		_arrows.append([up, down])
	_ok = ComicStyle.button("OK", 40)
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.custom_minimum_size = Vector2(ComicStyle.TOUCH.x, 112)
	_ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ok.pressed.connect(func() -> void:
		cursor = OK_SLOT
		submit())
	row.add_child(_ok)
	var hint := ComicStyle.label(hint_text(DisplayServer.is_touchscreen_available()), ComicStyle.LABEL, 27, Color(ComicStyle.INK, 0.85))
	hint.name = "Hint"
	add_child(hint)


static func hint_text(touch: bool) -> String:
	if touch:
		return "TAP THE ARROWS TO PICK, THEN OK"
	# "JUMP", not "A": A is a letter key on a keyboard; JUMP is A on the pad and
	# Space/Enter on keys.
	return "UP / DOWN LETTER  ·  LEFT / RIGHT MOVE  ·  JUMP NEXT"


## Start entry pre-filled with `initials` (the last ones used, like pinball).
func open(initials: String = HighScoreTable.DEFAULT_INITIALS) -> void:
	letters.clear()
	for c in HighScoreTable.sanitize_initials(initials):
		letters.append(c)
	cursor = 0
	idle = 0.0
	_done = false
	_held_dir = ""
	_mute_dirs = false
	show()
	_refresh()
	_arm()


func _arm() -> void:
	armed = false
	_ok.disabled = true
	await get_tree().create_timer(ARM_DELAY).timeout
	armed = true
	if is_instance_valid(_ok):
		_ok.disabled = false


func initials() -> String:
	return "".join(letters)


func submit() -> void:
	if _done or not armed or not is_visible_in_tree():
		return
	_done = true
	submitted.emit(initials())


# --- Editing (shared by every input path) -------------------------------------

func dial(step: int) -> void:
	if cursor >= OK_SLOT:
		return
	letters[cursor] = HighScoreTable.cycle_letter(letters[cursor], step)
	_refresh()


func move(step: int) -> void:
	cursor = clampi(cursor + step, 0, OK_SLOT)
	_blink = 0.0
	_refresh()


## JUMP / Enter: next stop, or save on OK.
func advance() -> void:
	if cursor >= OK_SLOT:
		submit()
	else:
		move(1)


func type_letter(c: String) -> void:
	cursor = mini(cursor, OK_SLOT - 1)
	letters[cursor] = c
	move(1)


func _touch_dial(slot: int, step: int) -> void:
	if not armed:
		return
	idle = 0.0
	cursor = slot
	dial(step)


func _select(slot: int) -> void:
	if armed:
		idle = 0.0
		cursor = slot
		_refresh()


# --- Input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# Keys and pad stop here so nothing behind the card (the frozen player, GUI focus)
	# sees them. Touch/mouse fall through to the buttons.
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	get_viewport().set_input_as_handled()
	if not armed or not event.is_pressed() or event.is_echo():
		return
	idle = 0.0
	if event is InputEventKey:
		_key(event as InputEventKey)
	elif event.is_action_pressed("ui_cancel"):
		move(-1)


func _key(event: InputEventKey) -> void:
	if event.keycode == KEY_BACKSPACE:
		move(-1)
		return
	var c := String.chr(event.unicode).to_upper() if event.unicode > 32 else ""
	if c != "" and c in HighScoreTable.ALPHABET:
		type_letter(c)
		_mute_dirs = true


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_blink += delta
	_paint_blink()
	if not armed:
		return
	idle += delta
	if idle >= IDLE_SAVE_SECONDS:
		cursor = OK_SLOT
		submit()
		return
	if Input.is_action_just_pressed("ui_accept"):
		idle = 0.0
		advance()
		return
	_poll_direction(delta)


func _poll_direction(delta: float) -> void:
	var dir := ""
	var tapped := false
	for action in DIRECTIONS:
		# just_pressed first: a tap pressed AND released between two frames never
		# reads as is_action_pressed, and would be lost.
		if Input.is_action_just_pressed(action):
			dir = action
			tapped = true
			break
		if Input.is_action_pressed(action):
			dir = action
	if dir == "":
		_mute_dirs = false
	if _mute_dirs or dir == "":
		_held_dir = ""
		return
	idle = 0.0
	if tapped or dir != _held_dir:
		_held_dir = dir
		_held_time = 0.0
		_step(dir)
		return
	_held_time += delta
	if _held_time >= REPEAT_DELAY:
		_held_time -= REPEAT_RATE
		_step(dir)


func _step(dir: String) -> void:
	match dir:
		"ui_up": dial(1)
		"ui_down": dial(-1)
		"ui_left": move(-1)
		"ui_right": move(1)


func _refresh() -> void:
	for i in _slots.size():
		_slots[i].text = letters[i]
		var box := _box_selected if i == cursor else _box_letter
		for state in ["normal", "hover", "pressed", "disabled"]:
			_slots[i].add_theme_stylebox_override(state, box)
		for arrow in _arrows[i]:
			arrow.active = i == cursor
	var on_ok := cursor == OK_SLOT
	for state in ["normal", "hover"]:
		if on_ok:
			_ok.add_theme_stylebox_override(state, _box_ok_selected)
		else:
			_ok.add_theme_stylebox_override(state, ComicStyle.box(ComicStyle.PAPER))
	_ok.add_theme_color_override("font_color", ComicStyle.CREAM if on_ok else ComicStyle.INK)
	_ok.add_theme_color_override("font_hover_color", ComicStyle.CREAM if on_ok else ComicStyle.INK)
	_paint_blink()


## Pinball's steps(2) blink: the selected letter's red underline (or the selected OK)
## toggles every BLINK_SECONDS.
func _paint_blink() -> void:
	var on := int(_blink / BLINK_SECONDS) % 2 == 0
	for i in _underlines.size():
		_underlines[i].visible = i == cursor and on
	_ok.modulate.a = 0.75 if cursor == OK_SLOT and not on else 1.0
