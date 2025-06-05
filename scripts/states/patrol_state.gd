extends EnemyState
class_name PatrolState

var direction: int = -1
var move_speed: float = 100.0
var patrol_start_x: float
var patrol_end_x: float

func enter_state(enemy: Enemy) -> void:
	super.enter_state(enemy)
	patrol_start_x = enemy.global_position.x
	patrol_end_x = patrol_start_x + 500.0

func physics_update(delta: float) -> void:
	enemy.animated_sprite_2d.play("walk")
	
	if _should_chase_player():
		enemy.enemy_state_machine.change_state("ChasePlayerState")
		return
	
	if _should_turn():
		direction *= -1
	
	_move_and_animate(delta)

func _should_chase_player() -> bool:
	# Use squared distance for better performance (avoid sqrt calculation)
	var dist_squared = enemy.position.distance_squared_to(Globals.player.position)
	
	# Close range detection (50^2 = 2500)
	if dist_squared < 2500:
		return true
		
	# Persist mode long range detection (250^2 = 62500)
	if dist_squared < 62500 and enemy.persist_enabled:
		return true
		
	# Player near ground detection for non-persist enemies
	if Globals.player.is_near_ground() and not enemy.persist_enabled:
		return true
		
	return false

func _should_turn() -> bool:
	# Check for wall collisions
	if direction < 0 and enemy.ray_cast_2d_left_wall.is_colliding():
		return true
	if direction > 0 and enemy.ray_cast_2d_right_wall.is_colliding():
		return true
	
	# Random direction change for more natural patrolling
	return randi_range(0, 130) == 2

func _move_and_animate(delta: float) -> void:
	enemy._update_sprite_direction(direction)
	var target_velocity = direction * move_speed
	enemy.velocity.x = move_toward(enemy.velocity.x, target_velocity, 2000 * delta)
