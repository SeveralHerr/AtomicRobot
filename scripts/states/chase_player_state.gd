extends EnemyState
class_name ChasePlayerState

## Focused state that only handles chasing the player (movement logic)

func enter_state(enemy: Enemy) -> void:
	super.enter_state(enemy)
	enemy.velocity.x = 0
	enemy.animated_sprite_2d.play("walk")

func exit_state(enemy: Enemy) -> void:
	pass

func physics_update(delta: float) -> void:
	if enemy.has_state("AttackPlayerState"):
		if enemy.is_in_attack_range() and enemy.can_attack():
			enemy.enemy_state_machine.change_state("AttackPlayerState")	
	if enemy.has_state("PatrolState"):
		if not enemy.can_see_player():
			enemy.enemy_state_machine.change_state("PatrolState")
			

	enemy.move_towards_target(enemy.player.global_position, delta)
		
