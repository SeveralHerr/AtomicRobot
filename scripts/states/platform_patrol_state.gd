extends EnemyState
class_name PlatformPatrolState

## Edge-aware patrol along a raised platform, dropping coins on the street below.
## Also turns back at street furniture in her way (trees, lamps: BLOCKERS_GROUP): a
## ledge at canopy or lamp-head height otherwise walks the maid straight through it
## ("walking on top of the tree", then of the BuildingGroup1 lamp at x 2572).

const BLOCKERS_GROUP := &"patrol_blockers"
## How far ahead of her feet (px) the maid checks for leaves: half her sprite plus a step,
## so her front edge stops clear of the fringe.
const FOLIAGE_LOOKAHEAD := 22.0
## Probe height above her feet: mid-body, so a canopy far below or above is ignored.
const FOLIAGE_PROBE_RISE := 16.0

var direction: int = -1


func enter_state() -> void:
	enemy.ray_cast_2d_left_down.enabled = true
	enemy.ray_cast_2d_right_down.enabled = true
	enemy.animated_sprite_2d.play("walk")
	enemy.line_of_sight.enabled = true
	enemy.set_facing(direction)

func exit_state() -> void:
	enemy.line_of_sight.enabled = false

func update(delta: float) -> void:
	if enemy.has_state("AttackPlayerState") and enemy.can_attack() and enemy.is_player_in_line_of_sight():
		enemy.enemy_state_machine.change_state("AttackPlayerState")
		return

	if enemy.is_the_player_in_attack_range() and enemy.is_player_in_line_of_sight():
		# Hold and track. Don't run the patrol turn here: standing on a platform
		# edge makes should_turn() fire on its cooldown forever, and its set_facing
		# would fight _face_player() for the direction the maid is looking.
		enemy._face_player()
		enemy.animated_sprite_2d.play("idle")
		if absf(enemy.knockback_velocity.x) < 10.0:
			enemy.velocity.x = 0
		return

	if enemy.should_turn():
		direction *= -1
	elif foliage_ahead(enemy.global_position, direction, _foliage_rects()):
		direction *= -1
	enemy.set_facing(direction)
	enemy.animated_sprite_2d.play("walk")
	enemy.move_towards_target(enemy.global_position + Vector2(direction, 0), delta)


## World rect of a blocker's sprite (a tree's canopy and trunk, a lamp's post and head).
static func foliage_rect(tree: Sprite2D) -> Rect2:
	return tree.get_global_transform() * tree.get_rect()


## True when a step in `dir` from `feet` walks into foliage the maid is not already in.
static func foliage_ahead(feet: Vector2, dir: int, rects: Array) -> bool:
	var body := feet - Vector2(0, FOLIAGE_PROBE_RISE)
	var probe := body + Vector2(dir * FOLIAGE_LOOKAHEAD, 0)
	for r: Rect2 in rects:
		if r.has_point(probe) and not r.has_point(body):
			return true
	return false


func _foliage_rects() -> Array:
	var out := []
	for t in enemy.get_tree().get_nodes_in_group(BLOCKERS_GROUP):
		if t is Sprite2D:
			out.append(foliage_rect(t))
	return out
