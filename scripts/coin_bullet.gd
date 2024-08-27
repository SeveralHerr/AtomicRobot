extends RigidBody2D
class_name Bullet

@onready var area_2d: Area2D = $Area2D
@onready var coin_audio_player: AudioStreamPlayer2D = $CoinAudioPlayer
@onready var ground_area_2d: Area2D = $GroundArea2D

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var speed: float = 200.0
var direction: Vector2

var bounces_remaining: int = 30  # Number of times the bullet can bounce before it is destroyed

func start(_position: Vector2, _direction: Vector2) -> void:
	position = _position
	#direction = _direction.normalized()
	linear_velocity  = _direction * speed


func _process(delta: float) -> void:
	pass

func _hit(body: Node2D) -> void:
	if body is Player:
		body.receive_hit()
	set_collision_layer_value(10, false)
	
	await get_tree().create_timer(2).timeout


	freeze_mode = FREEZE_MODE_KINEMATIC
	freeze = true
	pass

func _ready() -> void:
	area_2d.body_entered.connect(_hit)
	await get_tree().create_timer(15).timeout
	queue_free()

func is_off_screen() -> bool:
	# Optional: Implement logic to detect if the bullet is off-screen
	# This can help in cleaning up bullets that leave the screen area
	return false
