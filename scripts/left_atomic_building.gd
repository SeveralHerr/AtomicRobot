extends Node2D
@onready var area_2d: Area2D = $Area2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	area_2d.body_entered.connect(func(body: Node2D): 
		if body is Player:
			animation_player.play("flip_off")
			await animation_player.animation_finished
			area_2d.queue_free()
		)
