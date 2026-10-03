extends Control

const GAME: PackedScene = preload("res://scenes/main.tscn")
const AnyButton := preload("res://scripts/any_button.gd")
@onready var fade_overlay: FadeOverlay = $FadeOverlay
var delay: bool = false
var is_transitioning: bool = false

func _ready() -> void:
	$Timer.timeout.connect(_delay)
	fade_overlay.fade_in()

func _input(event: InputEvent) -> void:
	if delay and not is_transitioning and AnyButton.is_press(event):
		_start_transition()

func _start_transition() -> void:
	is_transitioning = true
	await fade_overlay.fade_out()
	await get_tree().create_timer(1).timeout
	get_tree().change_scene_to_packed(GAME)

func _delay() -> void:
	delay = true
