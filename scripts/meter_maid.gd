extends Enemy
class_name MeterMaid

func _ready() -> void:
	super._ready()
	enemy_state_machine.add_state("PatrolState", PatrolState.new(self))
	enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new(self))
	enemy_state_machine.add_state("AttackPlayerState", AttackPlayerState.new(self))
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new(self))
	
	enemy_state_machine.change_state("ChasePlayerState")
	
	
func can_attack() -> bool: 
	return attack_timer.is_stopped()


func attack() -> void:
	if not attack_timer.is_stopped():
		return


	await animated_sprite_2d.animation_finished
	if health <= 0:
		return
	velocity.x = 0
	animated_sprite_2d.play("idle")
	
