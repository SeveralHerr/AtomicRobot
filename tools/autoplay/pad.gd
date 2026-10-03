extends Node

## Virtual controller. Turns a brain intent, or a scripted press/release, into REAL
## key events through Input.parse_input_event — the same path a keyboard takes — so
## polled code (Input.is_action_pressed) and event code (_input -> State.handle_input,
## the menus' AnyButton) both see the bot exactly as they see a player.

## Physics frames a tap stays down. One frame is enough for an edge; two survives
## the input buffer flushing a press and its release into the same frame.
const TAP_FRAMES := 2
## Physics frames the jump button is held: releasing early halves the jump
## (JumpState), so a bot that only tapped could never clear a gap.
const JUMP_HOLD_FRAMES := 18

var _held := {}
## action -> physics frames until the automatic release of a tap/jump.
var _timers := {}
## action -> physics frames before it may be tapped again. Without a gap, an intent
## held for many frames re-presses on the frame the tap releases, so polled edge
## detectors (Player._process_lane_input) never see the key come up.
var _cooldown := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	for action in _cooldown.keys():
		_cooldown[action] -= 1
		if _cooldown[action] <= 0:
			_cooldown.erase(action)
	for action in _timers.keys():
		_timers[action] -= 1
		if _timers[action] <= 0:
			_timers.erase(action)
			release(action)
			_cooldown[action] = TAP_FRAMES


func press(action: StringName) -> void:
	if _held.get(action, false):
		return
	_held[action] = true
	Input.parse_input_event(event_for(action, true))


func release(action: StringName) -> void:
	if not _held.get(action, false):
		return
	_held.erase(action)
	_timers.erase(action)
	Input.parse_input_event(event_for(action, false))


## Press now, release automatically after `frames` physics frames.
func tap(action: StringName, frames: int = TAP_FRAMES) -> void:
	if _held.get(action, false) or _cooldown.has(action):
		return
	press(action)
	_timers[action] = frames


func is_held(action: StringName) -> bool:
	return _held.get(action, false)


func release_all() -> void:
	for action in _held.keys():
		release(action)


## Holds/taps whatever `intent` asks for (see brain.gd) and lets go of the rest.
func apply(intent: Dictionary) -> void:
	steer(intent.get("x", 0))
	_hold_if(&"Run", intent.get("run", false))
	_hold_if(&"Crouch", intent.get("crouch", false))
	# Event-driven actions need a fresh press each time: tap, never hold.
	if intent.get("attack", false):
		tap(&"Attack")
	if intent.get("jump", false):
		tap(&"ui_accept", JUMP_HOLD_FRAMES)
	var lane: int = intent.get("lane", 0)
	if lane < 0:
		tap(&"ui_up")
	elif lane > 0:
		tap(&"ui_down")


## Left/right only: scripted steps steer without releasing a held Run or Crouch.
func steer(x: int) -> void:
	_hold_if(&"ui_right", x > 0)
	_hold_if(&"ui_left", x < 0)


func _hold_if(action: StringName, on: bool) -> void:
	if _timers.has(action):
		return
	if on:
		press(action)
	else:
		release(action)


## A copy of the action's first key binding, so the event is indistinguishable from
## the real key. Falls back to an InputEventAction for actions with no key.
static func event_for(action: StringName, pressed: bool) -> InputEvent:
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				var k := e.duplicate() as InputEventKey
				k.pressed = pressed
				return k
	var a := InputEventAction.new()
	a.action = action
	a.pressed = pressed
	return a
