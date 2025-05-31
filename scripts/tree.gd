extends Sprite2D
@onready var cpu_particles_2d: CPUParticles2D = $CPUParticles2D
@onready var cpu_particles_2d_2: CPUParticles2D = $CPUParticles2D2
var timer: Timer

func _ready() -> void:
	# Set up timer
	timer = Timer.new()
	add_child(timer)
	timer.wait_time = 2.0 # Check every 2 seconds
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func _on_timer_timeout() -> void:
	# Randomly toggle particles
	if randf() > 0.5: # 50% chance to toggle
		cpu_particles_2d.emitting = !cpu_particles_2d.emitting
		cpu_particles_2d_2.emitting = !cpu_particles_2d_2.emitting
