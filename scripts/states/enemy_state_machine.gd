extends Node
class_name EnemyStateMachine

var states = {}
var current_state: EnemyState = null
var enemy: Enemy

func _init(enemy: Enemy) -> void:
	self.enemy = enemy
	Globals.player_death.connect(_on_player_death)

	
func _on_player_death() -> void:
	print("Player died, changing state...")
	change_state("PatrolState")

func add_state(name: String, state: EnemyState) -> void:
	states[name] = state

func change_state(name: String) -> void:
	print(name)
	if current_state:
		current_state.exit_state(enemy)
	current_state = states[name]
	current_state.enter_state(enemy)

func handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(enemy, event)

func update(delta: float) -> void:
	if current_state:
		current_state.update(enemy, delta)
		
func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
