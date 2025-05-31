extends Node2D
class_name Bullet

const HIT_FX = preload("res://scenes/hit_fx.tscn")
@onready var area_2d: Area2D = $Area2D
@onready var coin_audio_player: AudioStreamPlayer2D = $CoinAudioPlayer
@onready var ground_area_2d: Area2D = $GroundArea2D

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var speed: float = 600.0
var direction: Vector2
var velocity: Vector2
var is_falling: bool = false
var has_hit_player: bool = false

func start(_position: Vector2, _direction: Vector2, is_arc: bool = false) -> void:
	position = _position
	coin_audio_player.play()
	if is_arc:
		velocity = _direction
	else: 
		velocity = _direction * speed

func _process(delta: float) -> void:
	if has_hit_player and is_falling:
		# Apply gravity when falling
		velocity.y += gravity * delta
	
	# Update position based on velocity
	position += velocity * delta

func _hit(body: Node2D) -> void:
	if body is Bullet or body is Enemy:
		return

	# Disable collision detection to prevent multiple hits
	area_2d.set_collision_layer_value(1, false)
	area_2d.set_collision_layer_value(9, false)	
	area_2d.set_collision_mask_value(1, false)
	area_2d.set_collision_mask_value(9, false)	
	
	if body is Player:
		body.receive_hit(global_position, 1)
		var instance = HIT_FX.instantiate()
		body.get_tree().root.add_child(instance)
		instance.global_position = global_position
		instance.start()
		
		# Mark as hit and start falling
		has_hit_player = true
		is_falling = true
		# Reduce horizontal velocity but keep some momentum
		velocity.x *= 0.3
		velocity.y = 0  # Reset vertical velocity before gravity takes over

	# Clean up after 4 seconds
	await get_tree().create_timer(4).timeout
	queue_free()

func _ready() -> void:
	area_2d.body_entered.connect(_hit)
	
	# Clean up after 15 seconds if nothing happens
	await get_tree().create_timer(15).timeout
	queue_free()

func is_off_screen() -> bool:
	# Optional: Implement logic to detect if the bullet is off-screen
	# This can help in cleaning up bullets that leave the screen area
	return false
