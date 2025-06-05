extends EnemyState
class_name AttackPlayerState

## Focused state for ranged attacks (coin throwing)

var is_attacking: bool = false

func enter_state(enemy: Enemy) -> void:
	super.enter_state(enemy)
	enemy.velocity.x = 0
	

#func exit_state(enemy: Enemy) -> void:
	#_cleanup_timers()

func physics_update(delta: float) -> void:
	if enemy.has_state("ChasePlayerState"):
		if not enemy.is_in_attack_range():
			enemy.enemy_state_machine.change_state("ChasePlayerState")
			
	if enemy.has_state("FindMeterState"):
		if enemy.coins <= 0:
			enemy.enemy_state_machine.change_state("FindMeterState")
		
	enemy.attack()

	#enemy.velocity.x = 0

	
	
	
	
	
	
	## Stop movement while attacking
	#enemy.velocity.x = move_toward(enemy.velocity.x, 0, 2000 * delta)
	#
	## Check if should return to chase
	#if not is_attacking:
		#var dist = enemy.position.distance_to(Globals.player.position)
		#if dist > enemy.attack_range:
			#enemy.enemy_state_machine.change_state("ChasePlayerState")
			#return

#func _start_attack() -> void:
	#if Globals.player.is_dead:
		#return
		#
	#if enemy.coins <= 0 and enemy.refills_enabled:
		#enemy.enemy_state_machine.change_state("FindMeterState")
		#return
	#
	#is_attacking = true
	#enemy.animated_sprite_2d.play("attack")
	#
	## Setup timer for next attack
	#if not enemy.timer.timeout.is_connected(_on_attack_cooldown):
		#enemy.timer.timeout.connect(_on_attack_cooldown)
	#enemy.timer.start()
	#
	#_spawn_coin_delayed()
#
#func _spawn_coin_delayed() -> void:
	#if enemy == null:
		#return
	#enemy.coins -= 1
	#Utils.throw_coin_delayed(enemy, 0.3)
	#
	#await enemy.animated_sprite_2d.animation_finished
	#if enemy == null or enemy.health <= 0:
		#return
		#
	#is_attacking = false
	#enemy.animated_sprite_2d.play("idle")
#
#func _on_attack_cooldown() -> void:
	#if enemy.line_of_sight.is_player_line_of_sight() and not is_attacking:
		#_start_attack()
	#else:
		#enemy.enemy_state_machine.change_state("ChasePlayerState")
#
#func _cleanup_timers() -> void:
	#if enemy.timer.timeout.is_connected(_on_attack_cooldown):
		#enemy.timer.timeout.disconnect(_on_attack_cooldown)
	#enemy.timer.stop()
