extends Node2D

@onready var indicator: AnimatedSprite2D = $Indicator
@onready var area_2d: Area2D = $Area2D

const SEWER = preload("res://scenes/sewer2.tscn")

func _ready() -> void:
	indicator.hide()
	area_2d.body_entered.connect(_toggle_indicator)
	area_2d.body_exited.connect(_toggle_indicator)
	call_deferred("_reload_player")
	
func _reload_player() -> void:
	if Globals.player_last_position != null:
		Globals.player.move_player()
		#Globals.player_last_position = null
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Interact") and indicator.visible:
		Globals.player_last_position = Globals.player.position
		call_deferred("change_scene_to_sewer")

func change_scene_to_sewer() -> void:
	get_tree().change_scene_to_packed(SEWER)

func _toggle_indicator(body: Node2D) -> void:
	if body is Player:
		indicator.visible = !indicator.visible
		
