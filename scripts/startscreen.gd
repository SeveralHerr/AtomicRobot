extends Control

const CHARACTER_SELECT: PackedScene = preload("res://scenes/character_select.tscn")
const AnyButton := preload("res://scripts/any_button.gd")
var delay: bool = false

func _ready() -> void:
	$Timer.timeout.connect(_delay)

func _input(event: InputEvent) -> void:
	if delay and AnyButton.is_press(event):
		_advance()

func _advance() -> void:
	get_tree().change_scene_to_packed(CHARACTER_SELECT)

func _delay() -> void: 
	delay = true
