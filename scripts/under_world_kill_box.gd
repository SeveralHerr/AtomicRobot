extends Area2D

func _ready() -> void:
	body_entered.connect(func(body: Node2D):
		var player: Player = get_tree().get_first_node_in_group("player").death()
		
		)
