extends MeterMaid
class_name MeleeMeterMaid

## Meter maid that uses melee attacks instead of ranged coin throwing

func _ready() -> void:
	# Configure melee-specific settings before calling super
	attack_range = 60
	coins = 0
	refills_enabled = false  # Melee doesn't need ammo
	super._ready()

func _setup_state_machine() -> void:
	enemy_state_machine = EnemyStateMachine.new(self)
	enemy_state_machine.add_state("PatrolState", PatrolState.new())
	enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new())
	enemy_state_machine.add_state("AttackPlayerState", MeleeAttackState.new())
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new())
	
	# No FindMeterState needed for melee enemies
	
	add_child(enemy_state_machine)
	enemy_state_machine.change_state("PatrolState")
