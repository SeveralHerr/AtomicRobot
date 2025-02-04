extends Node2D


@onready var attack_timer: Timer = $AttackTimer
const BRIEFCASE = preload("res://scenes/briefcase.tscn")

func _ready():
	attack_timer.timeout.connect(_on_attack_timer_timeout)

func _process(delta):
	pass


func _on_attack_timer_timeout() -> void:
	print("attacking")
	var instance = BRIEFCASE.instantiate()
	instance.position = Vector2.ZERO
	#instance.global_position = global_positionA
	add_child(instance)
