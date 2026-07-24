extends Control

@onready var virtual_joystick_2: JoystickControl = $"Virtual Joystick2"
@onready var jump_ui: CenterContainer = $JumpButton
@onready var attack_ui: CenterContainer = $AttackButton
@onready var jump_button: Button = $JumpButton/Button
@onready var attack_button: Button = $AttackButton/Button
@onready var crouch_ui: CenterContainer = $CrouchUI
@onready var crouch_button: Button = $CrouchUI/Button
@onready var interact_ui: CenterContainer = $InteractButton
@onready var interact_button: Button = $InteractButton/Button
@onready var run_ui: CenterContainer = $RunButton
@onready var run_button: Button = $RunButton/Button


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func is_running_on_mobile() -> bool:
	return OS.has_feature("mobile")

func _ready() -> void:

	if not virtual_joystick_2.visible:
		jump_ui.hide()
		attack_ui.hide()
		crouch_ui.hide()
		interact_ui.hide()
		run_ui.hide()
	else:
		jump_button.pressed.connect(_on_jump)
		attack_button.pressed.connect(_on_attack)
		crouch_button.pressed.connect(_on_crouch)
		interact_button.pressed.connect(_on_interact)
		run_button.pressed.connect(_on_run)

func _on_jump() -> void:
	trigger(true, "ui_accept")

func _on_attack() -> void:
	trigger(true, "Attack")

func _on_crouch() -> void:
	trigger(true, "ui_down")
	pass

func _on_interact() -> void:
	trigger(true, "Interact")

func _on_run() -> void:
	trigger(true, "Run")

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var touch_pos = event.position
			if jump_button.get_global_rect().has_point(touch_pos):
				_on_jump()
			if attack_button.get_global_rect().has_point(touch_pos):
				_on_attack()
			if crouch_button.get_global_rect().has_point(touch_pos):
				_on_crouch()
			if interact_button.get_global_rect().has_point(touch_pos):
				_on_interact()
			if run_button.get_global_rect().has_point(touch_pos):
				_on_run()
		else:
			trigger(false, "ui_accept")
			jump_button.release_focus()

			trigger(false, "Attack")
			attack_button.release_focus()

			trigger(false, "ui_down")
			crouch_button.release_focus()

			trigger(false, "Interact")
			interact_button.release_focus()

			trigger(false, "Run")
			run_button.release_focus()

func trigger(status: bool, input_name: String) -> void:
	var custom_event = InputEventAction.new()
	custom_event.action = input_name
	custom_event.pressed = status  
	Input.parse_input_event(custom_event)
	
