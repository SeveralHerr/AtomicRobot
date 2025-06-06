extends EnemyState
class_name AttackPlayerState

var attack_finished: bool = false

func enter_state() -> void:
	attack_finished = false
	call_deferred("attack")
	
	
func attack() -> void:
	enemy.velocity.x = 0
	enemy._face_player()
	enemy.animated_sprite_2d.play("attack")

	Utils.throw_coin_delayed(enemy, 0.55)
	enemy.coins -= 1
	enemy.attack_timer.start()
	
	await enemy.animated_sprite_2d.animation_finished
	enemy.animated_sprite_2d.play("idle")
	attack_finished = true
func update(delta: float) -> void:
	if not attack_finished:
		return
		
	
	
	if enemy.has_state("ChasePlayerState") and not enemy.can_attack():
		enemy.enemy_state_machine.change_state("ChasePlayerState")
		return
			
	if enemy.has_state("FindMeterState") and enemy.coins <= 0:
		enemy.enemy_state_machine.change_state("FindMeterState")
		return
		
