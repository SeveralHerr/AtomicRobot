extends Node2D

@onready var sweeping_attack: Node2D = $"."
@onready var area_2d: Area2D = $Area2D
@onready var area_2d_2: Area2D = $Area2D2
@onready var area_2d_3: Area2D = $Area2D3

var _initial_x_position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.body_entered.connect(_hit)
	area_2d_2.body_entered.connect(_hit)
	area_2d_3.body_entered.connect(_hit)

	_initial_x_position = position.x
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x += .75
	if position.x >= 548:
		print("detected change")


func _hit(body: Node2D) -> void:
	pass # Replace with function body.

func _on_attack_timer_timeout() -> void:
	print("move", position)
	position.x = _initial_x_position

	pass # Replace with function body.
