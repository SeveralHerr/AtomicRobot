extends CPUParticles2D
@onready var timer: Timer = $Timer

var active: bool = false

func start() -> void:
	timer.start()
	timer.timeout.connect(_toggle)
func stop() -> void:
	emitting = false
	timer.stop()
	timer.timeout.disconnect(_toggle)


func _toggle() -> void:
	emitting = true
		
