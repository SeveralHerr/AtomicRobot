extends Node2D

@onready var area_2d: Area2D = $Area2D
@onready var coin_audio_player: AudioStreamPlayer2D = $CoinAudioPlayer

var node: Node2D
# Speed at which the bullet moves
var bullet_speed: float = 70.0
var original_position: Vector2
var direction

func _process(delta: float) -> void:
	position +=  direction * bullet_speed * delta

func _ready() -> void:

	area_2d.body_entered.connect(_hit)
	coin_audio_player.play()
	
	direction = (Globals.player.position - position).normalized()
	await get_tree().create_timer(5).timeout
	queue_free()

func _hit(body: Node2D) -> void:
	if body is Player:
		#print("hit")
		Globals.player.receive_hit()
	queue_free()
