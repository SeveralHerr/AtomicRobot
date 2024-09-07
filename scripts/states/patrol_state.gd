extends EnemyState
class_name PatrolState

var direction: int = -1


func physics_update(delta: float) -> void:
	if enemy.line_of_sight.is_player_line_of_sight():
		enemy.enemy_state_machine.change_state("ChasePlayerState")
		
	if not enemy.ray_cast_2d_left.is_colliding():
		direction = 1
	elif enemy.ray_cast_2d_left.is_colliding() and enemy.ray_cast_2d_left2.is_colliding() and direction == -1:
		direction = 1
	elif not enemy.ray_cast_2d_right.is_colliding():
		direction = -1
	elif enemy.ray_cast_2d_right.is_colliding() and enemy.ray_cast_2d_right2.is_colliding() and direction == 1:
		direction = -1

	enemy._update_sprite_direction(direction)
	enemy.velocity.x = move_toward(enemy.velocity.x, direction * 50, 2009 * delta)
		
