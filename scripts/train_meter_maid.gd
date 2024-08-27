extends Enemy
class_name TrainMeterMaid



func _ready() -> void:
	enemy_state_machine = EnemyStateMachine.new(self)
	enemy_state_machine.add_state("EnemyAttackState", EnemyAttackState.new())

	enemy_state_machine.change_state("EnemyAttackState")
	Globals.player_death.connect(_on_player_death)
	

	
func _on_player_death() -> void:
	print("Player died, changing state...")
	enemy_state_machine.change_state("EnemyAttackState")

func _process(delta: float) -> void:
	enemy_state_machine.update(delta)
	

	
func _physics_process(delta: float) -> void:
	enemy_state_machine.physics_update(delta)
	
