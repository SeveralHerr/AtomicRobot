extends Node2D

@onready var player_detection: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D


var heal_amount: int = 1
var is_collected: bool = false

func _ready() -> void:
	player_detection.body_entered.connect(_on_player_entered)


func _on_player_entered(body: Node2D) -> void:
	if body is Player and not is_collected:
		player_detection.body_entered.disconnect(_on_player_entered)
		collect_heart(body)

func collect_heart(player: Player) -> void:
	is_collected = true
	
	# Heal the player
	player.add_heart(heal_amount)
	
	# Visual feedback - could add particles or tween here
	if sprite:
		sprite.modulate = Color.TRANSPARENT
	
	# Wait a moment for sound then remove
	await get_tree().create_timer(0.1).timeout
	queue_free()
