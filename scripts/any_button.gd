extends RefCounted

## "Press any button" check shared by the front-end splash screens. Arcade cabinets
## have no keyboard or mouse, so a joypad button press must count too. Stick motion
## is deliberately excluded: a resting stick drifting past the deadzone is not intent.
static func is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	return (event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed
