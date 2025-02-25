extends Node2D

@onready var sweeping_attack: Node2D = $"."
@onready var area_2d: Area2D = $Area2D
@onready var area_2d_2: Area2D = $Area2D2
@onready var area_2d_3: Area2D = $Area2D3


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.body_entered.connect(_hit)
	area_2d.body_entered.connect(_hit)
	area_2d.body_entered.connect(_hit)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x += 1


func _hit(body: Node2D) -> void:
	pass # Replace with function body.
