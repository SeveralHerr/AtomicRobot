extends Node2D
class_name Bullet

@onready var area_2d: Area2D = $Area2D
@onready var coin_audio_player: AudioStreamPlayer2D = $CoinAudioPlayer
@onready var ground_area_2d: Area2D = $GroundArea2D


var node: Node2D
# Speed at which the bullet moves
var bullet_speed: float = 400.0
var original_position: Vector2
var direction
var player_only: bool = false
var is_on_ground: bool = false

func _process(delta: float) -> void:
	position +=  direction * bullet_speed * delta

func _ready() -> void:

	area_2d.body_entered.connect(_hit)
	ground_area_2d.body_entered.connect(_on_ground)
	coin_audio_player.play()
	
	direction = (Globals.player.position - position).normalized()
	await get_tree().create_timer(15).timeout
	queue_free()
	
func _on_ground(body: Node2D) -> void:

	is_on_ground = true
	

func _hit(body: Node2D) -> void:
	if body is Player:
		#print("hit")
		Globals.player.receive_hit()
		queue_free()
	elif not player_only:
		queue_free()
		pass
