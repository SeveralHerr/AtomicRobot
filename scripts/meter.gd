extends Node2D
class_name Meter

@onready var coin_particles: CPUParticles2D = $CoinParticles
#@onready var timer: Timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Globals.meters.append(self)
	#timer.timeout.connect(_timer)
	pass # Replace with function body.
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func play_animation() -> void:
	#$AnimatedSprite2D.play("Trigger")
	coin_particles.emitting = true
	#timer.start()
#	Globals.meters.erase(self)
	#await get_tree().create_timer(1).timeout
	
	#$AnimatedSprite2D.play("Idle")
	#coin_particles.hide()
