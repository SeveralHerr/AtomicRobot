extends CenterContainer

@onready var button: Button = $Button
const STARTSCREEN = "res://scenes/startscreen.tscn"

func _ready() -> void:
	hide()
	button.pressed.connect(_on_click)
	Globals.player_death.connect(_show_ui)
	pass 

func _on_click() -> void:
	Globals.reset()
	get_tree().change_scene_to_file(STARTSCREEN)
	pass

func _show_ui() -> void:
	await get_tree().create_timer(1).timeout
	show()
