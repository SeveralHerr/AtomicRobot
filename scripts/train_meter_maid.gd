extends Enemy
class_name TrainMeterMaid

## Special meter maid that only attacks (used in train sequences)

func _ready() -> void:
	_setup_state_machine()
	_setup_initial_state()
	Globals.player_death.connect(_on_player_death)

func _setup_state_machine() -> void:
	enemy_state_machine = EnemyStateMachine.new(self)
	enemy_state_machine.add_state("EnemyAttackState", EnemyAttackState.new())
	add_child(enemy_state_machine)
	enemy_state_machine.change_state("EnemyAttackState")

func _setup_initial_state() -> void:
	node = Globals.player.get_parent()

func _on_player_death() -> void:
	# Reset to attack state when player dies
	enemy_state_machine.change_state("EnemyAttackState")

func _process(delta: float) -> void:
	enemy_state_machine.update(delta)

func _physics_process(delta: float) -> void:
	if enemy_state_machine.enemy == null:
		return
		
	_apply_gravity(delta)
	enemy_state_machine.physics_update(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 300 * delta
