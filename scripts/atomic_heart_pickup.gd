extends Node2D

## The scene root is z 2, over trees (z 1) and crates: hearts sit at trunk feet, and
## under the leaves the white-outlined atom read as a speech bubble lost in the tree.
## (test_heart_draw_order.gd). Its Glow child + collect burst match PowerupPickup.

@onready var player_detection: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D


var heal_amount: int = 1
var is_collected: bool = false

## Every live heart, level-placed or knocked loose at runtime (door reward, boss phases).
const GROUP := "atomic_hearts"


func _ready() -> void:
	add_to_group(GROUP)
	player_detection.body_entered.connect(_on_player_entered)


func _on_player_entered(body: Node2D) -> void:
	if body is Player and not is_collected:
		player_detection.body_entered.disconnect(_on_player_entered)
		collect_heart(body)

func collect_heart(player: Player) -> void:
	is_collected = true
	
	# Heal the player
	player.add_heart(heal_amount)
	
	ScreenShake.apply_shake(4, 0.2)
	await PowerupGlow.collect_burst(self, sprite).finished
	queue_free()
