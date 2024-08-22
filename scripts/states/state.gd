extends Node

class_name State

func enter_state(player: Player) -> void:
	pass

func exit_state(player: Player) -> void:
	pass

func handle_input(player: Player, event: InputEvent) -> void:
	pass

func update(player: Player, delta: float) -> void:
	pass
