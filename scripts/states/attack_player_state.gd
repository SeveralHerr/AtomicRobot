extends EnemyState
class_name AttackPlayerState

var attack_finished: bool = false
var is_player_crouched: bool = false

func enter_state() -> void:
	enemy.animated_sprite_2d.frame_changed.connect(_on_frame_changed.bind(enemy))
	attack_finished = false
	enemy.velocity.x = 0
	is_player_crouched = enemy.player.state_machine.current_state is CrouchState
	enemy.animated_sprite_2d.play("attack")
	
func exit_state() -> void:
	enemy.animated_sprite_2d.frame_changed.disconnect(_on_frame_changed.bind(enemy))
			
func _on_frame_changed(enemy: Enemy):
	if enemy.animated_sprite_2d.animation == "attack" and enemy.animated_sprite_2d.frame == 6:
		attack()
	elif enemy.animated_sprite_2d.animation == "attack" and enemy.animated_sprite_2d.frame == 4:
		await enemy.get_tree().create_timer(0.2).timeout
		Utils.shake_node2d(enemy, 2, 0.2)

	
func attack() -> void:
	enemy._face_player()
	Utils.throw_coin_from_enemy(enemy, false, 10 if is_player_crouched else 0)
	enemy.coins -= 1
	enemy.attack_timer.start()
	
	await enemy.animated_sprite_2d.animation_finished
	
	if not enemy.enemy_state_machine.current_state is DeadEnemyState:
		enemy.animated_sprite_2d.play("idle")
	attack_finished = true
	
func update(delta: float) -> void:
	enemy._face_player()
	if not attack_finished:
		return
		
	if enemy.has_state("PlatformPatrolState"):
		enemy.enemy_state_machine.change_state("PlatformPatrolState")
		return
		
	if enemy.has_state("FindMeterState") and enemy.coins <= 0:
		enemy.enemy_state_machine.change_state("FindMeterState")
		return		
	

	if enemy.has_state("ChasePlayerState") and not enemy.can_attack():
		enemy.enemy_state_machine.change_state("ChasePlayerState")
		return
			

		
