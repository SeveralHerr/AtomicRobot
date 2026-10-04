extends RefCounted

## Picade X HAT sends keyboard keys (stick = arrows, buttons 1-6 = LCtrl, LAlt,
## Space, LShift, Z, X, Esc). Every remappable action needs a default key the
## cabinet can press, or the game is unplayable there.

var _T  # assertion helper injected by run_tests.gd

const CABINET_KEYS := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_CTRL, KEY_ALT,
	KEY_SPACE, KEY_SHIFT, KEY_Z, KEY_X, KEY_ESCAPE, KEY_ENTER]


func setup() -> void:
	InputRemap.reset_to_defaults()


func _cabinet_key(action: String) -> int:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var code: int = e.physical_keycode if e.physical_keycode else e.keycode
			if CABINET_KEYS.has(code):
				return code
	return KEY_NONE


func test_every_action_has_a_cabinet_key() -> String:
	for action in InputRemap.ACTIONS:
		if _cabinet_key(action) == KEY_NONE:
			return "no Picade key for " + action
	return ""


func test_buttons_are_not_shared_between_play_actions() -> String:
	var seen := {}
	for action in ["ui_accept", "Attack", "Interact", "Run", "Crouch"]:
		var code := _cabinet_key(action)
		if seen.has(code):
			return "%s and %s share a cabinet button" % [seen[code], action]
		seen[code] = action
	return ""


## Held Ctrl/Alt (buttons 1/2) must not stop other buttons from matching.
func test_modifier_held_still_matches_other_actions() -> String:
	var jump := InputEventKey.new()
	jump.physical_keycode = KEY_SPACE
	jump.keycode = KEY_SPACE  # browsers send both
	jump.pressed = true
	jump.ctrl_pressed = true
	jump.alt_pressed = true
	return _T.assert_true(jump.is_action_pressed("ui_accept"), "Space with Ctrl+Alt held")
