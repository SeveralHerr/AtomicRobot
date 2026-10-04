class_name PartyCode
extends RefCounted

## The title's Party Code: up up down down left right left right B A. Directions are
## the remappable ui_* actions (arrows, WASD, d-pad); B and A are the keys or the pad's
## face buttons. Fed every title event; says whether the title should still treat the
## press as "any button". Not a scored secret (see Globals.party_mode).

enum Step { IGNORED, HELD, DONE }

const SEQUENCE: Array[StringName] = [&"up", &"up", &"down", &"down", &"left", &"right",
	&"left", &"right", &"b", &"a"]
const DIRECTIONS := {&"up": &"ui_up", &"down": &"ui_down", &"left": &"ui_left", &"right": &"ui_right"}

var progress := 0


## Every code token `event` can stand for. KEY_A is both "left" (WASD) and "a".
static func tokens(event: InputEvent) -> Array[StringName]:
	var out: Array[StringName] = []
	if not ((event is InputEventKey and not event.echo) or event is InputEventJoypadButton) \
			or not event.pressed:
		return out
	for token in DIRECTIONS:
		if event.is_action(DIRECTIONS[token], true):
			out.append(token)
	if event is InputEventKey:
		var k: Key = event.physical_keycode if event.physical_keycode else event.keycode
		if k == KEY_B:
			out.append(&"b")
		elif k == KEY_A:
			out.append(&"a")
	elif event.button_index == JOY_BUTTON_B:
		out.append(&"b")
	elif event.button_index == JOY_BUTTON_A:
		out.append(&"a")
	return out


## HELD: the press belongs to the code (a direction, or the next B/A); the title must
## not advance on it. DONE: the code just completed. IGNORED: an ordinary press.
func feed(event: InputEvent) -> Step:
	var t := tokens(event)
	if t.is_empty():
		return Step.IGNORED
	if SEQUENCE[progress] in t:
		progress += 1
		if progress == SEQUENCE.size():
			progress = 0
			return Step.DONE
		return Step.HELD
	# A slip restarts the code; an extra "up" while still at "up up" keeps the start.
	progress = (2 if progress == 2 else 1) if &"up" in t else 0
	return Step.HELD if _is_direction(t) else Step.IGNORED


static func _is_direction(t: Array[StringName]) -> bool:
	for token in t:
		if DIRECTIONS.has(token):
			return true
	return false
