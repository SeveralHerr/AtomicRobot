extends EnemyState
class_name PlatformPatrolState

## Edge-aware patrol along a raised platform, dropping coins on the street below.

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
	enemy.set_facing(direction)
	enemy.animated_sprite_2d.play("walk")
	enemy.move_towards_target(enemy.global_position + Vector2(direction, 0), delta)
