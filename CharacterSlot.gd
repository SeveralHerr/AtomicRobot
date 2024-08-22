extends TextureRect

const GAME: PackedScene = preload("res://game2.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Button.pressed.connect(_on_press)
	pass # Replace with function body.

func _on_press() -> void:
	get_tree().change_scene_to_packed(GAME)
