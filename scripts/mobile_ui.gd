extends Control

## Touch layout: joystick on the left half, action buttons clustered bottom-right.
## Every action button is driven from _input() rather than Button.pressed so that a
## second finger works while the first one is holding the joystick (mouse emulation
## only ever tracks one touch index, so Button signals alone would drop those).
@onready var virtual_joystick_2: JoystickControl = $"Virtual Joystick2"
@onready var jump_ui: CenterContainer = $JumpButton
@onready var attack_ui: CenterContainer = $AttackButton
@onready var crouch_ui: CenterContainer = $CrouchUI
@onready var interact_ui: CenterContainer = $InteractButton
@onready var run_ui: CenterContainer = $RunButton
@onready var pause_ui: CenterContainer = $PauseButton
@onready var pause_button: Button = $PauseButton/Button

# Action button -> input action it drives. Held for as long as the finger is down.
@onready var _action_buttons: Dictionary = {
	jump_ui: "ui_accept",
	attack_ui: "Attack",
	crouch_ui: "ui_down",
	interact_ui: "Interact",
	run_ui: "Run",
}

# touch index -> the CenterContainer that finger is currently holding.
var _held: Dictionary = {}

const PRESSED_MODULATE := Color(0.7, 0.7, 0.7, 1.0)


func is_running_on_mobile() -> bool:
	return OS.has_feature("mobile")

func _ready() -> void:
	# The joystick hides itself in _ready when there's no touchscreen (children are
	# ready before the parent), so it doubles as the "are we on touch?" flag.
	if not virtual_joystick_2.visible:
		for ui in _action_buttons:
			ui.hide()

	# Pause is always visible (desktop + mobile) and is intentionally outside the
	# hide-all-touch-buttons branch above. It keeps a normal Button signal so it
	# still works with a mouse on desktop.
	pause_button.pressed.connect(_on_pause)

func _on_pause() -> void:
	# Pause is a toggle, not a held input: press now so is_action_just_pressed picks
	# it up, release a frame later so the action doesn't stay stuck down.
	trigger(true, "pause")
	await get_tree().process_frame
	trigger(false, "pause")

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var ui := _button_at(event.position)
			if ui != null:
				_press(event.index, ui)
				get_viewport().set_input_as_handled()
		elif _held.has(event.index):
			_release(event.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _held.has(event.index):
		# Sliding off a button releases it, sliding onto another one takes it over.
		var ui := _button_at(event.position)
		if ui != _held[event.index]:
			_release(event.index)
			if ui != null:
				_press(event.index, ui)

func _button_at(point: Vector2) -> CenterContainer:
	for ui in _action_buttons:
		if ui.visible and ui.get_global_rect().has_point(point):
			return ui
	return null

func _press(index: int, ui: CenterContainer) -> void:
	_held[index] = ui
	ui.modulate = PRESSED_MODULATE
	trigger(true, _action_buttons[ui])

func _release(index: int) -> void:
	var ui: CenterContainer = _held[index]
	_held.erase(index)
	# Another finger may still be on the same button.
	if not _held.values().has(ui):
		ui.modulate = Color.WHITE
		trigger(false, _action_buttons[ui])

func _notification(what: int) -> void:
	# Losing focus (app backgrounded, pause menu) drops touch events, so let go of
	# everything instead of leaving an action stuck down.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		for index in _held.keys():
			_release(index)

func trigger(status: bool, input_name: String) -> void:
	var custom_event = InputEventAction.new()
	custom_event.action = input_name
	custom_event.pressed = status
	Input.parse_input_event(custom_event)
