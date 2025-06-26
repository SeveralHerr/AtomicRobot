extends Enemy
class_name MeterMaid



func _ready() -> void:
	super._ready()
	coins = 1
	#enemy_state_machine.add_state("PatrolState", PatrolState.new(self))
	enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new(self))
	enemy_state_machine.add_state("AttackPlayerState", AttackPlayerState.new(self))
	enemy_state_machine.add_state("FindMeterState", FindMeterState.new(self))
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new(self))
	
	enemy_state_machine.change_state("ChasePlayerState")
	
	#
#func can_attack() -> bool: 
	#return attack_timer.is_stopped()
#
#
	#
