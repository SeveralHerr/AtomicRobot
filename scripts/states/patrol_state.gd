extends EnemyState
class_name PatrolState

var direction: int = -1

func enter_state() -> void:
	enemy.animated_sprite_2d.play("walk")

func update(delta: float) -> void:
	if enemy.has_state("ChasePlayerState") and enemy.can_see_player():
		enemy.enemy_state_machine.change_state("ChasePlayerState")
	
	if _should_turn():
		direction *= -1
		
	if enemy.velocity.x == 0:
		enemy.animated_sprite_2d.play("idle")
	else:
		enemy.animated_sprite_2d.play("walk")

	
	# left or right
	enemy.move_towards_target(Vector2(direction, 0), delta)


func _should_turn() -> bool:
	# Check for wall collisions
	if direction < 0 and enemy.ray_cast_2d_left_wall.is_colliding():
		return true
	if direction > 0 and enemy.ray_cast_2d_right_wall.is_colliding():
		return true
	
	# Random direction change for more natural patrolling
	return randi_range(0, 130) == 2
