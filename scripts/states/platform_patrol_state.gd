extends EnemyState
class_name PlatformPatrolState

var direction: int = -1


func enter_state() -> void:
	enemy.ray_cast_2d_left_down.enabled = true
	enemy.ray_cast_2d_right_down.enabled = true
	enemy.animated_sprite_2d.play("walk")
	enemy.line_of_sight.enabled = true
	
func exit_state() -> void:
	enemy.line_of_sight.enabled = false
	
func update(delta: float) -> void:
	if enemy.should_turn():
		direction *= -1
	enemy._handle_direction(direction * -1)
		
	if enemy.has_state("AttackPlayerState") and (enemy.can_attack() and enemy.is_player_in_line_of_sight()):
		enemy.enemy_state_machine.change_state("AttackPlayerState")	
		return
	if enemy.is_the_player_in_attack_range()  and enemy.is_player_in_line_of_sight():
		enemy._face_player()
		enemy.animated_sprite_2d.play("idle")
		# Only stop movement if not being knocked back
		if abs(enemy.knockback_velocity.x) < 10.0:
			enemy.velocity.x = 0	
	else:
		enemy.animated_sprite_2d.play("walk")
		enemy.move_towards_target(enemy.global_position + Vector2(direction, 0), delta)
