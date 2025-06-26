extends CenterContainer
class_name  GameOver

const CHARACTER_SELECT ="res://scenes/character_select.tscn"
@onready var button: Button = $VBoxContainer/Button

func _ready() -> void:
	hide()
	button.grab_focus()
	button.pressed.connect(func(): 
		Globals.reset()
		get_tree().change_scene_to_file(CHARACTER_SELECT ))
		
	Globals.player_death.connect(func(): show())
