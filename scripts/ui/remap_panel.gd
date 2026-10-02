extends PanelContainer

## Pause-menu "Controls" screen: one row per InputRemap.ACTIONS entry with
## [Set] (replace every binding) and [Add] (append one). Built in code so the row list
## can never drift from InputRemap.ACTIONS. Joystick/keyboard only - no mouse needed.
##
## Listening: the next bindable press is captured in _input and swallowed so it neither
## presses a focused button nor reaches the game. Presses in the same frame as the
## Set/Add activation are ignored (that is the activating ui_accept itself), as are
## releases and echoes. LISTEN_TIMEOUT seconds of nothing cancels.

signal closed

const FONT := preload("res://styles/font_variation.tres")
const LISTEN_TIMEOUT := 5.0
const FONT_SIZE := 28
const BINDS_FONT_SIZE := 22

## Injectable so tests don't clobber the player's real settings file.
var settings_path: String = InputRemap.SETTINGS_PATH

var _rows := {}  # action -> {"binds": Label, "set": Button, "add": Button}
var _listen_action := ""
var _listen_add := false
var _armed_frame := -1
var _focus_return: Button
var _prompt: Label
var _timer: Timer
var _reset_button: Button
var _back_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	refresh()


func is_listening() -> bool:
	return _listen_action != ""


## Show the panel and put focus on the first row so a stick can drive it at once.
func open() -> void:
	visible = true
	refresh()
	first_focus().grab_focus()


func first_focus() -> Button:
	return _rows[InputRemap.ACTIONS.keys()[0]]["set"]


func refresh() -> void:
	for action in _rows:
		var labels := PackedStringArray()
		for ev in InputRemap.bindings(action):
			labels.append(InputRemap.event_label(ev))
		_rows[action]["binds"].text = ", ".join(labels) if labels.size() else "(none)"


func begin_listen(action: String, add: bool) -> void:
	_listen_action = action
	_listen_add = add
	_armed_frame = Engine.get_process_frames()
	_focus_return = _rows[action]["add" if add else "set"]
	_prompt.text = "Press a button for %s... (wait %ds to cancel)" % [
		InputRemap.ACTIONS[action], int(LISTEN_TIMEOUT)]
	_timer.start(LISTEN_TIMEOUT)


func cancel_listen() -> void:
	_end_listen("Cancelled.")


func _input(event: InputEvent) -> void:
	if not is_listening():
		return
	# Swallow everything while listening, including the activating press's release.
	get_viewport().set_input_as_handled()
	if Engine.get_process_frames() <= _armed_frame:
		return
	_capture(event)


## Bind `event` to the listened-for action. Returns true if it was taken.
func _capture(event: InputEvent) -> bool:
	# is_bindable already rejects releases, echoes and a resting stick.
	if not is_listening() or not InputRemap.is_bindable(event):
		return false
	var action := _listen_action
	var label := InputRemap.event_label(event)
	if _listen_add:
		if not InputRemap.add_binding(action, event):
			_end_listen("%s is already bound to %s." % [label, InputRemap.ACTIONS[action]])
			return true
	else:
		InputRemap.set_binding(action, event)
	InputRemap.save(settings_path)
	refresh()
	_end_listen("%s -> %s" % [InputRemap.ACTIONS[action], label])
	return true


func _end_listen(message: String) -> void:
	_timer.stop()
	_listen_action = ""
	_prompt.text = message
	if is_instance_valid(_focus_return) and is_inside_tree():
		_focus_return.grab_focus()


func _on_reset() -> void:
	InputRemap.reset_to_defaults()
	InputRemap.save(settings_path)
	refresh()
	_prompt.text = "Defaults restored."


func _on_back() -> void:
	if is_listening():
		return
	visible = false
	closed.emit()


func _build() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var header := _label("CONTROLS", 44)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 470)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(grid)

	for action in InputRemap.ACTIONS:
		var name_label := _label(InputRemap.ACTIONS[action])
		name_label.custom_minimum_size.x = 170
		grid.add_child(name_label)
		var binds := _label("", BINDS_FONT_SIZE)
		binds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binds.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		binds.custom_minimum_size.x = 100
		grid.add_child(binds)
		var set_btn := _button("Set", func(): begin_listen(action, false))
		var add_btn := _button("Add", func(): begin_listen(action, true))
		grid.add_child(set_btn)
		grid.add_child(add_btn)
		_rows[action] = {"binds": binds, "set": set_btn, "add": add_btn}

	_prompt = _label("Set replaces, Add keeps the old buttons too.", 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_prompt)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 40)
	vbox.add_child(bottom)
	_reset_button = _button("RESET DEFAULTS", _on_reset)
	_back_button = _button("BACK", _on_back)
	bottom.add_child(_reset_button)
	bottom.add_child(_back_button)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.timeout.connect(cancel_listen)
	add_child(_timer)


func _label(text: String, size := FONT_SIZE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(90, 42)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(on_pressed)
	return b
