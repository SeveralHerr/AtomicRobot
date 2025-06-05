extends Enemy
class_name MeterMaidMelee

func _ready() -> void:
	super._ready()
	enemy_state_machine.add_state("PatrolState", PatrolState.new(self))
	enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new())
	enemy_state_machine.add_state("AttackPlayerState", AttackPlayerState.new())
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new())
	
	enemy_state_machine.change_state("ChasePlayerState")
	
	
func can_attack() -> bool: 
	return attack_timer.is_stopped()


func attack() -> void:
	if not attack_timer.is_stopped():
		return

	animated_sprite_2d.play("attack")

	Utils.throw_coin_delayed(self, 0.3)
	coins -= 1
	attack_timer.start()
	await animated_sprite_2d.animation_finished
	if health <= 0:
		return
	velocity.x = 0
	animated_sprite_2d.play("idle")
	
