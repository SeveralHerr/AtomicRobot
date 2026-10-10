extends Node

const METER_MAID = preload("res://scenes/meter_maid.tscn")
const METER_MAID_MELEE = preload("res://scenes/meter_maid_melee.tscn")

## World px past the visible edge that an ambient spawn lands (before `offset`). The
## old rule put spawns viewport_width / 3 from the player: 426 px at the 1280-wide
## design view, whose edge sits 256 world px out (zoom 2.5) — so 170 px past it. Now
## the margin is fixed and the edge comes from the live view: a wider screen (16:9,
## phone) used to push spawns further out and stretch the walk-on, and one ~1900 px
## wide put them past Enemy.detection_range (600), so they never noticed the player.
const SPAWN_MARGIN := 1280.0 / 3.0 - 256.0


## X of a spawn just off the `side` (+1 right, -1 left) edge of a view centred on
## `view_x` that is `half_view` world px wide each way.
static func spawn_x(view_x: float, half_view: float, side: int, offset: float = 0.0) -> float:
	return view_x + side * (half_view + SPAWN_MARGIN + offset)


static func spawn_enemy(parent: Node2D, player: Node2D, offset: float = 50.0, force_spawn_right: bool = false) -> Node2D:
	var enemy 
	var rand = randi_range(0, 1)
	if rand == 1: 
		enemy = METER_MAID.instantiate()
	else: 
		enemy = METER_MAID_MELEE.instantiate()
	parent.call_deferred("add_child",enemy)
	
	# Randomly choose left or right side (randi() first: seeded runs keep their order).
	var side := 1 if (randi() % 2 == 1 or force_spawn_right) else -1
	# Measured off the VIEW, not the player: under an arena lock or a level edge the
	# camera stops following, and player-relative spawns landed on screen.
	var vp := player.get_viewport()
	var x := spawn_x(CarWarning.view_x(vp, player), CarWarning.half_view(vp), side, offset)

	# Spawn on a weighted random lane (biased toward the player's) for TMNT-style
	# depth pressure; _ready applies starting_lane + collision/z. The player's
	# baseline is the walkway FLOOR line, shared by every body, so handing it
	# straight over is safe — the enemy converts it with its own foot offset.
	if player is Player and player.lane_floor_y != INF:
		var lane := _pick_spawn_lane(player.current_lane)
		enemy.starting_lane = lane
		enemy.lane_floor_y = player.lane_floor_y
		enemy.global_position = Vector2(
			x, Lanes.stand_y(player.lane_floor_y, lane, Lanes.measure_foot_offset(enemy)))
	else:
		enemy.global_position = Vector2(x, player.position.y)
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

static func spawn_wave(parent: Node2D, player: Node2D, count: int = 3, offset: float = 50.0) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for i in range(count):
		var enemy = spawn_enemy(parent, player, offset)
		enemies.append(enemy)
	return enemies
