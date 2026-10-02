class_name InputRemap
extends RefCounted

## Runtime input remapping: each action may hold one or many buttons.
## Bindings persist in the shared settings file as plain Dictionaries
## (never raw InputEvent Objects) and are validated on load.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "input"
## Ordered remappable action -> UI label. debug_menu deliberately excluded.
const ACTIONS := {
	"ui_up": "Up", "ui_down": "Down", "ui_left": "Left", "ui_right": "Right",
	"ui_accept": "Jump", "Attack": "Attack", "Interact": "Interact", "Run": "Run",
	"Crouch": "Crouch", "pause": "Pause" }
const AXIS_THRESHOLD := 0.5
## Upper bound for a plain (modifier-free) keycode, incl. the KEY_SPECIAL range.
const MAX_KEYCODE := KEY_SPECIAL * 2


## True for events a player can bind: key/pad-button presses and a pushed stick.
static func is_bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and _key_code(event) != 0
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) >= AXIS_THRESHOLD
	return false


## Fresh device-agnostic copy (device -1 = any pad; encoders often show as several).
static func normalize(event: InputEvent) -> InputEvent:
	return _decode(_encode(event))


## Human-readable text, e.g. "Key F", "Pad Btn 2", "Pad Axis 1-".
static func event_label(event: InputEvent) -> String:
	var d := _encode(event)
	match d.get("t", ""):
		"key": return "Key " + OS.get_keycode_string(d["code"])
		"btn": return "Pad Btn %d" % d["idx"]
		"axis": return "Pad Axis %d%s" % [d["axis"], "+" if d["val"] > 0 else "-"]
	return event.as_text() if event else ""


static func bindings(action: String) -> Array[InputEvent]:
	return InputMap.action_get_events(action)


## Replaces every binding of `action` with the single normalized `event`.
static func set_binding(action: String, event: InputEvent) -> void:
	var e := normalize(event)
	if e == null:
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, e)


## Appends `event`; false (no-op) if an equivalent event is already bound.
static func add_binding(action: String, event: InputEvent) -> bool:
	var d := _encode(event)
	if d.is_empty():
		return false
	for existing in InputMap.action_get_events(action):
		if _encode(existing) == d:
			return false
	InputMap.action_add_event(action, _decode(d))
	return true


## Restores every ACTIONS entry from project.godot.
static func reset_to_defaults() -> void:
	for action in ACTIONS:
		var setting = ProjectSettings.get_setting("input/" + action)
		if not setting is Dictionary or not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for e in setting.get("events", []):
			if e is InputEvent:
				InputMap.action_add_event(action, e.duplicate())


## Writes the input section, keeping every other section of the file.
static func save(path := SETTINGS_PATH) -> void:
	var config := ConfigFile.new()
	config.load(path)  # missing file -> start empty
	if config.has_section(SECTION):
		config.erase_section(SECTION)
	for action in ACTIONS:
		var list: Array = []
		for e in InputMap.action_get_events(action):
			var d := _encode(e)
			if not d.is_empty():
				list.append(d)
		config.set_value(SECTION, action, list)
	config.save(path)


## Applies saved bindings. Missing, unknown or invalid entries leave defaults.
static func load_and_apply(path := SETTINGS_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK or not config.has_section(SECTION):
		return
	for action in config.get_section_keys(SECTION):
		if not ACTIONS.has(action) or not InputMap.has_action(action):
			continue
		var raw = config.get_value(SECTION, action)
		if not raw is Array:
			continue
		var events: Array[InputEvent] = []
		for d in raw:
			var e := _decode(d)
			if e != null:
				events.append(e)
		if events.is_empty():
			continue  # never leave an action unbindable
		InputMap.action_erase_events(action)
		for e in events:
			InputMap.action_add_event(action, e)


static func _key_code(k: InputEventKey) -> int:
	return k.physical_keycode if k.physical_keycode != 0 else k.keycode


## Event -> plain Dictionary ({} if unsupported).
static func _encode(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var code := _key_code(event)
		return {"t": "key", "code": code} if code != 0 else {}
	if event is InputEventJoypadButton:
		return {"t": "btn", "idx": event.button_index}
	if event is InputEventJoypadMotion:
		return {"t": "axis", "axis": event.axis, "val": signf(event.axis_value)}
	return {}


## Validated Dictionary -> fresh event; null for anything malformed.
static func _decode(d: Variant) -> InputEvent:
	if not d is Dictionary:
		return null
	match d.get("t"):
		"key":
			var code = d.get("code")
			if typeof(code) != TYPE_INT or code <= 0 or code >= MAX_KEYCODE:
				return null
			var k := InputEventKey.new()
			k.physical_keycode = code
			k.device = -1
			return k
		"btn":
			var idx = d.get("idx")
			if typeof(idx) != TYPE_INT or idx < 0 or idx >= JOY_BUTTON_MAX:
				return null
			var b := InputEventJoypadButton.new()
			b.button_index = idx
			b.device = -1
			return b
		"axis":
			var axis = d.get("axis")
			var val = d.get("val")
			if typeof(axis) != TYPE_INT or axis < 0 or axis >= JOY_AXIS_MAX:
				return null
			if typeof(val) not in [TYPE_INT, TYPE_FLOAT] or absf(val) != 1.0:
				return null
			var m := InputEventJoypadMotion.new()
			m.axis = axis
			m.axis_value = val
			m.device = -1
			return m
	return null
