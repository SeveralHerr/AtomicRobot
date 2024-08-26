extends Node2D

@onready var spawn_point: Node2D = $SpawnPoint


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Globals.player.position = spawn_point.position
	Globals.player.state_machine.change_state("ClimbState")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
