extends Node2D
class_name Shaker

@export var randomStrength: float = 30.0
@export var shakeFade: float = 10.0

var rng = RandomNumberGenerator.new()
var shake_strength: float = 0.0
var obj: Node2D
var original_position: Vector2
var is_shaking: bool = false
var shake_duration: float = 1.0
var elapsed_time: float = 0.0

func _init(new_obj: Node2D) -> void:
	obj = new_obj
	original_position = obj.position

func apply_shake(_randomStrength: float = 1.0, _duration: float = 1.0):
	shake_strength = _randomStrength
	shake_duration = _duration
	elapsed_time = 0.0
	is_shaking = true

func process(delta: float) -> void:
	if is_shaking:
		elapsed_time += delta
		
		if elapsed_time < shake_duration:
			# Apply shake effect
			shake_strength = lerpf(shake_strength, 0, shakeFade * delta)
			obj.position.x = original_position.x + randomOffset()
			obj.position.y = original_position.y + randomOffset()
		else:
			# Restore the original position and stop shaking
			obj.position = original_position
			is_shaking = false

func randomOffset() -> float:
	return rng.randf_range(-shake_strength, shake_strength)
