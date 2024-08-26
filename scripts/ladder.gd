extends Node2D

const MAIN = "res://game2.tscn"

@onready var spawn_point: Node2D = $"../SpawnPoint"
@onready var area_2d: Area2D = $Area2D
@onready var climb_label: Label = $ClimbLabel
@onready var ladder_exit_area_2d: Area2D = $LadderExit/Area2D

var can_climb: bool = false

func _ready() -> void:
	area_2d.body_entered.connect(_on_enter)
	area_2d.body_exited.connect(_on_exit)

	ladder_exit_area_2d.body_exited.connect(_on_ladder_exit_exit)

		
func _on_ladder_exit_exit(body: Node2D) -> void:
	if not ladder_exit_area_2d.body_entered.is_connected(_on_ladder_exit_enter):
		ladder_exit_area_2d.body_entered.connect(_on_ladder_exit_enter)

func _on_ladder_exit_enter(body: Node2D) -> void:
	call_deferred("_change_scene")
	
func _change_scene() -> void:
	get_tree().change_scene_to_file(MAIN)

	
func _input(event: InputEvent) -> void:
	if event.is_action("Interact") and can_climb and Globals.player.is_on_floor():
		Globals.player.state_machine.change_state("ClimbState")
		Globals.player.position.x = spawn_point.position.x
		
func _on_exit(body: Node2D) -> void:
	if body is Player: 
		can_climb = false
		climb_label.hide()

func _on_enter(body: Node2D) -> void:
	if body is Player: 
		can_climb = true
		
		if body.is_on_floor():
			climb_label.show()

		
