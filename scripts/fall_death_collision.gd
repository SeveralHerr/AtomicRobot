extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_enter)
	pass # Replace with function body.


func _on_enter(body: Node2D) -> void:
	if body is Player:
		# A pit is fatal regardless of orbs left — spend whatever health remains.
		# (Was a flat 3, which killed outright back when 1 hit point == 1 orb.)
		body.take_damage(body.health)
