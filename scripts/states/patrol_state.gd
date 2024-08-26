extends EnemyState
class_name PatrolState

var direction: int = -1


func enter_state(new_enemy: Enemy) -> void:
	enemy = new_enemy
	#if not enemy.range_area_2d.body_entered.is_connected(_target):
		#enemy.range_area_2d.body_entered.connect(_target)
		
		
#func exit_state(enemy: Enemy) -> void:
	#if enemy.range_area_2d.body_entered.is_connected(_target):
		#enemy.range_area_2d.body_entered.disconnect(_target)

	
func _target(body: Node2D) -> void:
	if body is Player:
		enemy.enemy_state_machine.change_state("ChasePlayerState")


func physics_update(delta: float) -> void:
	if Globals.player.is_dead:
		return
	
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
		

	_update_sprite_direction(enemy)
	enemy.velocity.x = move_toward(enemy.velocity.x, direction * 50, 2009 * delta)

		
		
func _update_sprite_direction(enemy: Enemy) -> void:
	enemy.animated_sprite_2d.flip_h = (direction == -1)
