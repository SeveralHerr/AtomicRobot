extends Node

@export var randomStrength: float = 30.0
@export var shakeFade: float = 10.0

var camera: Camera2D
var rng = RandomNumberGenerator.new()
var shake_strength: float = 0.0


var obj: Node2D
var original_position: Vector2
var is_shaking: bool = false
var shake_duration: float = 1.0
var elapsed_time: float = 0.0
var player: Player

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	
func apply_shake(_randomStrength: float = 1.0, _duration: float = 1.0):
	if is_shaking:
		elapsed_time = 0
		return

	if not player:
		return
	original_position = Vector2(player.camera_2d.offset)
	shake_strength = _randomStrength
	shake_duration = _duration
	elapsed_time = 0.0
	is_shaking = true

func _process(delta: float) -> void:
	if is_shaking:
		elapsed_time += delta
		
		if elapsed_time < shake_duration - 0.8:
			# Apply shake effect
			if not player:
				return
			shake_strength = lerpf(shake_strength, 0, shakeFade * delta)
			player.camera_2d.offset.x = original_position.x + randomOffset()
			player.camera_2d.offset.y  = original_position.y +  randomOffset()
		else:
			# Restore the original position and stop shaking
			if player:
				player.camera_2d.offset.x = original_position.x
				player.camera_2d.offset.y  = original_position.y 
			is_shaking = false
			print("ready")

func randomOffset() -> float:
	return rng.randf_range(-shake_strength, shake_strength)
