extends TextureRect

const GAME: PackedScene = preload("res://game.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Globals.cody_unlocked:
		$Character.show()
		$Button.pressed.connect(_on_press)
	else:
		$Character.hide()
		

	pass # Replace with function body.

func _on_press() -> void:
	Globals.cody_selected = true
	get_tree().change_scene_to_packed(GAME)
