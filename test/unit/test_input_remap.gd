extends RefCounted

## InputRemap: bindable filter, normalize, set/add, persistence, tamper safety.

var _T  # assertion helper injected by run_tests.gd
const PATH := "user://test_input_remap.cfg"


func setup() -> void:
	InputRemap.reset_to_defaults()
	DirAccess.remove_absolute(PATH)


func teardown() -> void:
	setup()


func _key(code: int, pressed := true, echo := false) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = pressed
	k.echo = echo
	return k


func _btn(idx: int, pressed := true) -> InputEventJoypadButton:
	var b := InputEventJoypadButton.new()
	b.button_index = idx
	b.pressed = pressed
	b.device = 3  # arbitrary pad: normalized bindings must still match
	return b

func _axis(axis: int, val: float) -> InputEventJoypadMotion:
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = val
	return m

func _first_failure(results: Array) -> String:
	var fails := results.filter(func(r): return r != "")
	return "" if fails.is_empty() else fails[0]


func test_every_action_exists_in_input_map() -> String:
	for action in InputRemap.ACTIONS:
		if not InputMap.has_action(action):
			return "missing InputMap action " + action
	return _T.assert_false(InputRemap.ACTIONS.has("debug_menu"), "debug_menu excluded")


func test_is_bindable() -> String:
	var click := InputEventMouseButton.new(); click.pressed = true
	var touch := InputEventScreenTouch.new(); touch.pressed = true
	return _first_failure([
		_T.assert_true(InputRemap.is_bindable(_key(KEY_F)), "key press"),
		_T.assert_false(InputRemap.is_bindable(_key(KEY_F, false)), "key release"),
		_T.assert_false(InputRemap.is_bindable(_key(KEY_F, true, true)), "key echo"),
		_T.assert_true(InputRemap.is_bindable(_btn(2)), "btn press"),
		_T.assert_false(InputRemap.is_bindable(_btn(2, false)), "btn release"),
		_T.assert_true(InputRemap.is_bindable(_axis(1, -0.7)), "axis pushed"),
		_T.assert_false(InputRemap.is_bindable(_axis(1, 0.3)), "axis in deadzone"),
		_T.assert_false(InputRemap.is_bindable(click), "mouse"),
		_T.assert_false(InputRemap.is_bindable(touch), "touch"),
		_T.assert_false(InputRemap.is_bindable(null), "null"),
	])


func test_normalize_strips_device_and_modifiers() -> String:
	var k := _key(0)
	k.keycode = KEY_G
	k.shift_pressed = true
	k.device = 2
	var nk: InputEventKey = InputRemap.normalize(k)
	var nb: InputEventJoypadButton = InputRemap.normalize(_btn(5))
	var nm: InputEventJoypadMotion = InputRemap.normalize(_axis(1, -0.6))
	return _first_failure([
		_T.assert_eq(nk.physical_keycode, KEY_G, "keycode fallback"),
		_T.assert_false(nk.shift_pressed, "no modifiers"),
		_T.assert_eq(nk.device, -1, "key any device"),
		_T.assert_true(nk != k, "fresh copy"),
		_T.assert_eq(nb.button_index, 5, "btn idx"),
		_T.assert_eq(nb.device, -1, "btn any device"),
		_T.assert_eq(nm.axis, 1, "axis"),
		_T.assert_eq(nm.axis_value, -1.0, "axis sign"),
		_T.assert_eq(nm.device, -1, "axis any device"),
	])


func test_event_label() -> String:
	return _first_failure([
		_T.assert_eq(InputRemap.event_label(_key(KEY_F)), "Key F", "key"),
		_T.assert_eq(InputRemap.event_label(_btn(2)), "Pad Btn 2", "btn"),
		_T.assert_eq(InputRemap.event_label(_axis(1, -0.9)), "Pad Axis 1-", "axis-"),
		_T.assert_eq(InputRemap.event_label(_axis(0, 0.9)), "Pad Axis 0+", "axis+"),
	])


func test_set_binding_replaces_all() -> String:
	InputRemap.set_binding("Attack", _btn(4))
	var b := InputRemap.bindings("Attack")
	return _first_failure([
		_T.assert_eq(b.size(), 1, "single binding"),
		_T.assert_eq(InputRemap.event_label(b[0]), "Pad Btn 4", "the new one"),
	])


func test_add_binding_appends_and_dedupes() -> String:
	var before := InputRemap.bindings("Attack").size()
	var added := InputRemap.add_binding("Attack", _btn(7))
	var dup := InputRemap.add_binding("Attack", _btn(7))
	var bad := InputRemap.add_binding("Attack", InputEventMouseButton.new())
	return _first_failure([
		_T.assert_true(added, "first add"),
		_T.assert_false(dup, "duplicate rejected"),
		_T.assert_false(bad, "unsupported rejected"),
		_T.assert_eq(InputRemap.bindings("Attack").size(), before + 1, "one appended"),
	])


func test_many_buttons_all_trigger_action() -> String:
	InputRemap.set_binding("Attack", _key(KEY_J))
	InputRemap.add_binding("Attack", _btn(1))
	InputRemap.add_binding("Attack", _axis(2, 0.8))
	return _first_failure([
		_T.assert_true(InputMap.event_is_action(_key(KEY_J), "Attack"), "key"),
		_T.assert_true(InputMap.event_is_action(_btn(1), "Attack"), "btn on pad 3"),
		_T.assert_true(InputMap.event_is_action(_axis(2, 0.9), "Attack"), "axis"),
		_T.assert_false(InputMap.event_is_action(_key(KEY_F), "Attack"), "old key gone"),
	])


func test_save_load_roundtrip() -> String:
	InputRemap.set_binding("Crouch", _btn(9))
	InputRemap.add_binding("Crouch", _axis(1, 1.0))
	InputRemap.save(PATH)
	InputRemap.reset_to_defaults()
	InputRemap.load_and_apply(PATH)
	var labels := InputRemap.bindings("Crouch").map(InputRemap.event_label)
	return _T.assert_eq(labels, ["Pad Btn 9", "Pad Axis 1+"], "restored bindings")


func test_save_preserves_other_sections() -> String:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", 0.25)
	cfg.save(PATH)
	InputRemap.save(PATH)
	cfg = ConfigFile.new()
	cfg.load(PATH)
	return _first_failure([
		_T.assert_eq(cfg.get_value("audio", "volume"), 0.25, "audio kept"),
		_T.assert_true(cfg.has_section_key("input", "Attack"), "input written"),
	])


func test_saved_file_holds_no_objects() -> String:
	InputRemap.save(PATH)
	var text := FileAccess.get_file_as_string(PATH)
	return _T.assert_false(text.contains("Object("), "plain data only")


func test_tampered_config_is_ignored() -> String:
	var defaults := InputRemap.bindings("Attack").map(InputRemap.event_label)
	var jump := InputRemap.bindings("ui_accept").map(InputRemap.event_label)
	var cfg := ConfigFile.new()
	cfg.set_value("input", "Attack", [{"t": "key", "code": -5}, {"t": "btn", "idx": "x"},
		{"t": "axis", "axis": 99, "val": 1.0}, {"t": "axis", "axis": 0, "val": 0.3},
		"junk", 42, {"t": "nope"}])
	cfg.set_value("input", "ui_accept", "not an array")
	cfg.set_value("input", "debug_menu", [{"t": "btn", "idx": 1}])
	cfg.set_value("input", "Run", [{"t": "btn", "idx": 3}, {"t": "btn", "idx": 9999}])
	cfg.save(PATH)
	InputRemap.load_and_apply(PATH)
	return _first_failure([
		_T.assert_eq(InputRemap.bindings("Attack").map(InputRemap.event_label), defaults,
			"all-invalid list keeps defaults"),
		_T.assert_eq(InputRemap.bindings("ui_accept").map(InputRemap.event_label), jump,
			"non-array keeps defaults"),
		_T.assert_false(InputMap.event_is_action(_btn(1), "debug_menu"), "unknown action ignored"),
		_T.assert_eq(InputRemap.bindings("Run").map(InputRemap.event_label), ["Pad Btn 3"],
			"valid entries kept, invalid skipped"),
	])


func test_garbage_file_is_ignored() -> String:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[input\nAttack=}}}{{ not cfg")
	f.close()
	var defaults := InputRemap.bindings("Attack").size()
	InputRemap.load_and_apply(PATH)
	InputRemap.load_and_apply("user://does_not_exist.cfg")
	return _T.assert_eq(InputRemap.bindings("Attack").size(), defaults, "defaults untouched")


func test_reset_restores_defaults() -> String:
	var expected := InputRemap.bindings("ui_accept").map(InputRemap.event_label)
	InputRemap.set_binding("ui_accept", _btn(11))
	InputRemap.reset_to_defaults()
	return _T.assert_eq(InputRemap.bindings("ui_accept").map(InputRemap.event_label),
		expected, "defaults back")
