extends CPUParticles2D
@onready var timer: Timer = $Timer

var active: bool = false

func start() -> void:
	if not timer.timeout.is_connected(_toggle):
		timer.start()
		timer.timeout.connect(_toggle)
func stop() -> void:
	emitting = false
	timer.stop()
	if timer.timeout.is_connected(_toggle):
		timer.timeout.disconnect(_toggle)


func _toggle() -> void:
	emitting = true
		
