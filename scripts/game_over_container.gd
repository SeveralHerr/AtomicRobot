extends CenterContainer
class_name  GameOver

const CHARACTER_SELECT = preload("res://scenes/character_select.tscn")
@onready var button: Button = $VBoxContainer/Button

func _ready() -> void:
	hide()
	button.grab_focus()
	button.pressed.connect(func(): 
		get_tree().change_scene_to_packed(CHARACTER_SELECT) )
