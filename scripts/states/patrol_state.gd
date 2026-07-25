extends EnemyState
class_name PatrolState

## Idle back-and-forth walk until the player is spotted.

var direction: int = -1


func enter_state() -> void:
	enemy.animated_sprite_2d.play("walk")
	enemy.line_of_sight.enabled = true
	enemy.set_facing(direction)

func exit_state() -> void:
	enemy.line_of_sight.enabled = false

func update(delta: float) -> void:
	if enemy.has_state("ChasePlayerState") and enemy.can_see_player_threshold(0.8) and enemy.is_player_in_line_of_sight():
		enemy.enemy_state_machine.change_state("ChasePlayerState")
		return

	# should_turn() owns the turn cooldown (Enemy.turn_cooldown, ticked in
	# _physics_process) and flips `facing` itself. This state used to keep a second
	# private cooldown and then call _face_player() every frame on top, so a
	# patrolling maid stared at the player while walking the other way — and the
	# two cooldowns could disagree about whether a turn had happened at all.
	if enemy.should_turn():
		direction *= -1

	enemy.set_facing(direction)
	enemy.animated_sprite_2d.play("walk")
	enemy.move_towards_target(enemy.global_position + Vector2(direction, 0), delta)
