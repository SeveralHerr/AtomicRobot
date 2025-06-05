extends Node
class_name EnemyStateMachine

var states = {}
var current_state: EnemyState = null
var enemy: Enemy

func _init(e: Enemy) -> void:
	enemy = e


func add_state(name: String, state: EnemyState) -> void:
	states[name] = state

func change_state(name: String) -> void:
	print("Enemy state", name)
	if current_state:
		current_state.exit_state(enemy)	
		
	current_state = states[name]

	current_state.enter_state(enemy)


func update(delta: float) -> void:
	#func _process(delta: float) -> void:
	#enemy.scale.x = sign((Globals.player.position - enemy.position).normalized().x)
	
	if current_state:
		current_state.update( delta)
		
