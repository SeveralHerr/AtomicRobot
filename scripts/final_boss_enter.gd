extends Sprite2D

const FINAL_BOSS = preload("res://scenes/boss_room.tscn")

@onready var area_2d: Area2D = $Area2D
func _ready() -> void:
	area_2d.body_entered.connect(_on_area_entered)
	
func _on_area_entered(body: Node2D) -> void:
	if body is Player:
		call_deferred("change_scene")

func change_scene(): 
	get_tree().change_scene_to_packed(FINAL_BOSS)
