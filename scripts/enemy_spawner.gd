extends Node

const METER_MAID = preload("res://scenes/meter_maid.tscn")


static func spawn_enemy(parent: Node2D, player: Node2D, viewport_size: Vector2, offset: float = 50.0, force_spawn_right: bool = false) -> Node2D:
	var enemy = METER_MAID.instantiate()
	parent.call_deferred("add_child",enemy)
	
	# Randomly choose left or right side
	var spawn_side = randi() % 2 # 0 for left, 1 for right
	var spawn_x = 0.0
	
	if force_spawn_right or spawn_side == 1:
		spawn_x = player.position.x + viewport_size.x / 3 + offset
	elif spawn_side == 0: # Left side
		spawn_x = player.position.x - viewport_size.x / 3 - offset

	# Set enemy position
	enemy.global_position = Vector2(spawn_x, player.position.y)
	return enemy

static func spawn_wave(parent: Node2D, player: Node2D, viewport_size: Vector2, count: int = 3, offset: float = 50.0) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for i in range(count):
		var enemy = spawn_enemy(parent, player, viewport_size, offset)
		enemies.append(enemy)
	return enemies
