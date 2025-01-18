extends Control

const CHARACTER_SELECT: PackedScene = preload("res://scenes/character_select.tscn")
var delay: bool = false

func _ready() -> void:
	$Timer.timeout.connect(_delay)

func _input(event: InputEvent) -> void:
	if delay:
		if event is InputEventMouseButton and event.pressed:
			get_tree().change_scene_to_packed(CHARACTER_SELECT)
		elif event is InputEventKey and event.pressed:
			get_tree().change_scene_to_packed(CHARACTER_SELECT)
		
func _delay() -> void: 
	delay = true
