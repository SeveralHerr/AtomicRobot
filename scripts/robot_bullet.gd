extends Node2D

@onready var area_2d: Area2D = $Area2D

var dir = 0
var player: Player
var lane: int = Lanes.GROUND_LANE

func _ready() -> void:
	area_2d.body_entered.connect(_hit)

func _physics_process(delta: float) -> void:
	if dir == 0:
		return

	position.x += dir * 10

func _process(delta: float) -> void:
	await get_tree().create_timer(1).timeout
	queue_free()

func _hit(body: Node2D):
	if body is Enemy and body.lane == lane:
		ScreenShake.apply_shake(7)
		body.receive_hit(player.damage)
		queue_free()
