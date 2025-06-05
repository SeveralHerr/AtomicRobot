extends MeterMaid
class_name MeleeMeterMaid

## Meter maid that uses melee attacks instead of ranged coin throwing

func _setup_state_machine() -> void:
	enemy_state_machine = EnemyStateMachine.new(self)
	enemy_state_machine.add_state("PatrolState", PatrolState.new())
	enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new())
	enemy_state_machine.add_state("AttackPlayerState", MeleeAttackState.new()) # Use melee instead of ranged
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new())
	
	# Melee meter maids don't need ammo, so no FindMeterState needed
	
	add_child(enemy_state_machine)
	enemy_state_machine.change_state("PatrolState")

func _ready() -> void:
	# Set shorter attack range for melee
	attack_range = 60
	# Melee enemies don't need coins
	coins = 0
	super._ready()
