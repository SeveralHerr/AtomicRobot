extends Enemy
class_name MeterMaidMelee

func _ready() -> void:
	super._ready()
	enemy_state_machine.add_state("PatrolState", PatrolState.new(self))
	enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new(self))
	enemy_state_machine.add_state("AttackPlayerState", AttackPlayerMeleeState.new(self))
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new(self))
	
	enemy_state_machine.change_state("ChasePlayerState")
	
	
func can_attack() -> bool: 
	return attack_timer.is_stopped()
