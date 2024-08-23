extends Node

class_name EnemyState

var enemy: Enemy

func enter_state(enemy: Enemy) -> void:
	pass

func exit_state(enemy: Enemy) -> void:
	pass

func handle_input(enemy: Enemy, event: InputEvent) -> void:
	pass

func update(enemy: Enemy, delta: float) -> void:
	pass
