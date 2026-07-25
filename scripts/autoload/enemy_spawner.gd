extends Node

const METER_MAID = preload("res://scenes/meter_maid.tscn")
const METER_MAID_MELEE = preload("res://scenes/meter_maid_melee.tscn")

static func spawn_enemy(parent: Node2D, player: Node2D, viewport_size: Vector2, offset: float = 50.0, force_spawn_right: bool = false) -> Node2D:
	var enemy 
	var rand = randi_range(0, 1)
	if rand == 1: 
		enemy = METER_MAID.instantiate()
	else: 
		enemy = METER_MAID_MELEE.instantiate()
	parent.call_deferred("add_child",enemy)
	
	# Randomly choose left or right side
	var spawn_side = randi() % 2 # 0 for left, 1 for right
	var spawn_x = 0.0
	
	if force_spawn_right or spawn_side == 1:
		spawn_x = player.position.x + viewport_size.x / 3 + offset
	elif spawn_side == 0: # Left side
		spawn_x = player.position.x - viewport_size.x / 3 - offset

	# Spawn on a weighted random lane (biased toward the player's) for TMNT-style
	# depth pressure; _ready applies starting_lane + collision/z. The player's
	# baseline is the walkway FLOOR line, shared by every body, so handing it
	# straight over is safe — the enemy converts it with its own foot offset.
	if player is Player and player.lane_floor_y != INF:
		var lane := _pick_spawn_lane(player.current_lane)
		enemy.starting_lane = lane
		enemy.lane_floor_y = player.lane_floor_y
		enemy.global_position = Vector2(
			spawn_x, Lanes.stand_y(player.lane_floor_y, lane, Lanes.measure_foot_offset(enemy)))
	else:
		enemy.global_position = Vector2(spawn_x, player.position.y)
	return enemy


## Spawn one enemy at an explicit world X on an explicit lane.
##
## `parent` MUST be a zero-transform node — pass `get_tree().current_scene`.
## global_position is applied while the node is still an orphan (add_child is
## deferred), so on a parent with a non-zero transform the enemy gets shifted by
## that transform once it is actually added.
static func spawn_enemy_at(parent: Node, player: Node2D, world_x: float, lane: int, melee: bool) -> Node2D:
	var enemy = (METER_MAID_MELEE if melee else METER_MAID).instantiate()
	var use_lane := Lanes.clamp_lane(lane)
	var y: float = player.position.y
	if player is Player and player.lane_floor_y != INF:
		enemy.lane_floor_y = player.lane_floor_y
		y = Lanes.stand_y(player.lane_floor_y, use_lane, Lanes.measure_foot_offset(enemy))
	else:
		# No walkway baseline captured yet — the virtual floors are unknown, so the
		# only safe place to stand is the real one.
		use_lane = Lanes.GROUND_LANE
	enemy.starting_lane = use_lane
	parent.call_deferred("add_child", enemy)
	enemy.global_position = Vector2(world_x, y)
	return enemy


static func _pick_spawn_lane(player_lane: int) -> int:
	if randf() < 0.4:
		return player_lane
	var others: Array[int] = []
	for l in range(Lanes.BACK_LANE, Lanes.FRONT_LANE + 1):
		if l != player_lane:
			others.append(l)
	return others[randi() % others.size()]

static func spawn_wave(parent: Node2D, player: Node2D, viewport_size: Vector2, count: int = 3, offset: float = 50.0) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for i in range(count):
		var enemy = spawn_enemy(parent, player, viewport_size, offset)
		enemies.append(enemy)
	return enemies
