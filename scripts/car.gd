extends Node2D

@onready var area_2d: Area2D = $Area2D

var shaker: Shaker

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.body_entered.connect(_hit)
	shaker = Shaker.new(self)

	pass # Replace with function body.

func _physics_process(delta: float) -> void:
	position.x -= delta * 200
	
func _process(delta: float) -> void:
	if position.x <= Globals.player.position.x - 2000:
		position.x = Globals.player.position.x +2000
		
	shaker.process(delta)

func _hit(body: Node2D) -> void:
	if body is Player:
		shaker.apply_shake(2)
		body.receive_hit()
