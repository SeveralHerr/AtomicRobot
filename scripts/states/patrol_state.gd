extends EnemyState
class_name PatrolState

var direction: int = -1
var move_speed: float = 100.0

func physics_update(delta: float) -> void:
	enemy.animated_sprite_2d.play("walk")
	
	# Check if player is in line of sight to chase
	if enemy.line_of_sight.is_player_line_of_sight():
		enemy.enemy_state_machine.change_state("ChasePlayerState")
		return
	
	# Calculate direction towards player
	var player_direction = (Globals.player.global_position - enemy.global_position).normalized()
	direction = sign(player_direction.x)
	
	# Update sprite direction
	enemy._update_sprite_direction(direction)
	
	# Move towards player with smooth acceleration
	var target_velocity = direction * move_speed
	enemy.velocity.x = move_toward(enemy.velocity.x, target_velocity, 2000 * delta)
		
