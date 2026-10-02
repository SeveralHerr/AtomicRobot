extends RefCounted

## Pause-menu Controls screen: Set replaces, Add appends, Reset restores, the activating
## press is never captured, and pause can't close the menu from inside the panel.

var _T

const PANEL := preload("res://scripts/ui/remap_panel.gd")
const MENU := "res://scenes/pause_menu.tscn"
const TMP := "user://test_remap_settings.cfg"

var _panel


func setup() -> void:
	InputRemap.reset_to_defaults()
	_panel = PANEL.new()
	_panel.settings_path = TMP
	(Engine.get_main_loop() as SceneTree).root.add_child(_panel)


func teardown() -> void:
	if is_instance_valid(_panel):
		_panel.free()
	InputRemap.reset_to_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _key(code: Key, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func _labels(action: String) -> Array:
	return InputRemap.bindings(action).map(func(e): return InputRemap.event_label(e))


func test_set_replaces_all_bindings() -> String:
	_panel.begin_listen("Attack", false)
	_panel._capture(_key(KEY_K))
	return _T.assert_eq(_labels("Attack"), [InputRemap.event_label(_key(KEY_K))], "Set")


func test_add_appends_a_second_binding() -> String:
	_panel.begin_listen("Attack", false)
	_panel._capture(_key(KEY_K))
	_panel.begin_listen("Attack", true)
	_panel._capture(_key(KEY_L))
	var want := [InputRemap.event_label(_key(KEY_K)), InputRemap.event_label(_key(KEY_L))]
	return _T.assert_eq(_labels("Attack"), want, "Add")


func test_reset_restores_defaults() -> String:
	var before := _labels("Attack")
	_panel.begin_listen("Attack", false)
	_panel._capture(_key(KEY_K))
	_panel._on_reset()
	return _T.assert_eq(_labels("Attack"), before, "Reset")


func test_capture_saves_to_injected_path() -> String:
	_panel.begin_listen("ui_accept", false)
	_panel._capture(_key(KEY_K))
	return _T.assert_true(FileAccess.file_exists(TMP), "binding saved to settings_path")


func test_row_shows_new_binding() -> String:
	_panel.begin_listen("Attack", false)
	_panel._capture(_key(KEY_K))
	var text: String = _panel._rows["Attack"]["binds"].text
	return _T.assert_eq(text, InputRemap.event_label(_key(KEY_K)), "row label refreshed")


func test_release_and_echo_are_ignored() -> String:
	_panel.begin_listen("Attack", false)
	var echo := _key(KEY_K)
	echo.echo = true
	_panel._capture(_key(KEY_K, false))
	_panel._capture(echo)
	return _T.assert_true(_panel.is_listening(), "still listening after release/echo")


## The ui_accept that pressed Set arrives in the same frame - it must not bind.
func test_activating_press_is_not_captured() -> String:
	var before := _labels("Attack")
	_panel.begin_listen("Attack", false)
	_panel._input(_key(KEY_ENTER))
	var r: String = _T.assert_eq(_labels("Attack"), before, "same-frame press ignored")
	if r != "":
		return r
	await (Engine.get_main_loop() as SceneTree).process_frame
	_panel._input(_key(KEY_K))
	return _T.assert_eq(_labels("Attack"), [InputRemap.event_label(_key(KEY_K))],
		"next-frame press bound")


func test_timeout_cancels_listening() -> String:
	_panel.begin_listen("Attack", false)
	_panel._timer.timeout.emit()
	return _T.assert_false(_panel.is_listening(), "timeout cancels")


func test_every_action_has_a_row() -> String:
	return _T.assert_eq(_panel._rows.keys(), InputRemap.ACTIONS.keys(), "rows match ACTIONS")


func test_menu_controls_button_swaps_panels() -> String:
	var menu: Node = load(MENU).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var remap = menu.get_node("CenterContainer/RemapPanel")
	var main: Control = menu.get_node("CenterContainer/Panel")
	remap.settings_path = TMP
	menu.get_node("CenterContainer/Panel/Margin/VBoxContainer/ControlsButton").pressed.emit()
	var opened: bool = remap.visible and not main.visible
	remap._on_back()
	var closed: bool = main.visible and not remap.visible
	menu.free()
	if not opened:
		return "Controls button did not show the remap panel"
	return _T.assert_true(closed, "Back returns to the main pause panel")
