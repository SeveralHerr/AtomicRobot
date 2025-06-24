extends EnemyState
class_name ChasePlayerState

## Focused state that only handles chasing the player (movement logic)

func enter_state() -> void:
	enemy.animated_sprite_2d.play("walk")
	enemy.line_of_sight.enabled = true
	
func exit_state() -> void:
	enemy.line_of_sight.enabled = false

func update(delta: float) -> void:
	if enemy.has_state("AttackPlayerState") and (enemy.can_attack() and enemy.is_player_in_line_of_sight()):
		enemy.enemy_state_machine.change_state("AttackPlayerState")	
		return
		
	if enemy.has_state("PatrolState") and (not enemy.can_see_player() and not enemy.is_player_in_line_of_sight()):
		enemy.enemy_state_machine.change_state("PatrolState")
		return
			
	# Handle animationd
	if not enemy.is_player_in_attack_range:
		enemy.move_towards_target(enemy.player.global_position, delta)
		enemy.animated_sprite_2d.play("walk")
	else:
		enemy._face_player()
		enemy.animated_sprite_2d.play("idle")
		enemy.velocity.x = 0	
		
	
