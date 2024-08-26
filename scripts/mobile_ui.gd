extends Control

@onready var virtual_joystick_2: VirtualJoystick = $"Virtual Joystick2"
@onready var jump_ui: CenterContainer = $JumpButton
@onready var attack_ui: CenterContainer = $AttackButton
@onready var jump_button: Button = $JumpButton/Button
@onready var attack_button: Button = $AttackButton/Button


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func is_running_on_mobile() -> bool:
	return OS.has_feature("mobile")

func _ready() -> void:

	if not virtual_joystick_2.visible:
		jump_ui.hide()
		attack_ui.hide()
	else:
		jump_button.pressed.connect(_on_jump)
		attack_button.pressed.connect(_on_attack)

func _on_jump() -> void:
	var custom_event = InputEventAction.new()
	custom_event.action = "ui_accept" 
	custom_event.pressed = true  
	Input.parse_input_event(custom_event)

func _on_attack() -> void:
	var custom_event = InputEventAction.new()
	custom_event.action = "Attack" 
	custom_event.pressed = true  
	Input.parse_input_event(custom_event)
	
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var touch_pos = event.position
			if jump_button.get_global_rect().has_point(touch_pos):
				_on_jump()
			if attack_button.get_global_rect().has_point(touch_pos):
				_on_attack()
		else:
			var custom_event = InputEventAction.new()
			custom_event.action = "ui_accept" 
			custom_event.pressed = false  
			Input.parse_input_event(custom_event)

			custom_event = InputEventAction.new()
			custom_event.action = "Attack" 
			custom_event.pressed = false  
			Input.parse_input_event(custom_event)
	
