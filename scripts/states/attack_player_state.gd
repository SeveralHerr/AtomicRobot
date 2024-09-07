extends EnemyState
class_name AttackPlayerState

var stand_still: bool = false

func enter_state(new_enemy: Enemy) -> void:
	enemy = new_enemy
	stand_still = false
	enemy.velocity.x =0

	# Immediately perform the attack
	_create_bullet()

func exit_state(enemy: Enemy) -> void:
	if enemy.timer.timeout.is_connected(_create_bullet):
		enemy.timer.timeout.disconnect(_create_bullet)
	enemy.timer.stop()

func _create_bullet() -> void:
	if Globals.player.is_dead:
		return
	
	if enemy.coins <= 0:
		enemy.enemy_state_machine.change_state("FindMeterState")
		return
	
	stand_still = true
	enemy.animated_sprite_2d.animation_finished.connect(throw_coin)
	enemy.animated_sprite_2d.play("ThrowCoin")

	# Start the cooldown timer after attacking
	if not enemy.timer.timeout.is_connected(_on_attack_cooldown):
		enemy.timer.timeout.connect(_on_attack_cooldown)
	enemy.timer.start()

func throw_coin() -> void:
	stand_still = false
	enemy.animated_sprite_2d.animation_finished.disconnect(throw_coin)
	
	var instance = enemy.COIN_BULLET.instantiate()
	enemy.coins -= 1
	enemy.node.add_child(instance)
	
	var pos = enemy.position + enemy.coin_spawn_point.position
	instance.start(pos, (Globals.player.position - pos).normalized())

	enemy.animated_sprite_2d.play("Idle")

func _on_attack_cooldown() -> void:
	# Attack is ready again, so check if we should continue attacking or change state
	if enemy.line_of_sight.is_player_line_of_sight():
		_create_bullet()  # Attack again if the player is still in sight
	else:
		enemy.enemy_state_machine.change_state("ChasePlayerState")
