extends Control


@onready var button: Button = $MarginContainer/VBoxContainer/Button
@onready var exit_button: Button = $MarginContainer/VBoxContainer/ExitButton

const CHARACTER_SELECT = preload("res://character_select.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button.pressed.connect(_return)
	exit_button.pressed.connect(_close)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _return() -> void: 
	get_tree().change_scene_to_packed(CHARACTER_SELECT)
	
func _close() -> void:
	queue_free()
	
	
