extends MeterMaid
class_name PersistentMeterMaid

## Meter maid that persists in the scene (not spawned via code)
## Has different behavior patterns due to persist_enabled flag

func _ready() -> void:
	persist_enabled = true
	super._ready()

func _setup_state_machine() -> void:
	enemy_state_machine = EnemyStateMachine.new(self)
	enemy_state_machine.add_state("PatrolState", PersistentPatrolState.new())
	enemy_state_machine.add_state("ChasePlayerState", PersistentChaseState.new())
	enemy_state_machine.add_state("AttackPlayerState", AttackPlayerState.new())
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new())
	
	# Persistent meter maids don't need to refill (they're not code-spawned)
	if refills_enabled:
		enemy_state_machine.add_state("FindMeterState", FindMeterState.new())
	
	add_child(enemy_state_machine)
	enemy_state_machine.change_state("PatrolState")

func _should_despawn() -> bool:
	# Persistent enemies never despawn due to distance
	return false