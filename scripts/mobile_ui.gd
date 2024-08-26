extends Control

@onready var virtual_joystick_2: VirtualJoystick = $"Virtual Joystick2"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func is_running_on_mobile() -> bool:
	return OS.has_feature("mobile")

func _ready() -> void:
	virtual_joystick_2.hide()
	if is_running_on_mobile():
		print("Running on a mobile device")
		virtual_joystick_2.show()
		# Adjust game settings for mobile, e.g., scaling, input methods
	else:
		print("Running on a desktop device")
		# Adjust game settings for desktop
