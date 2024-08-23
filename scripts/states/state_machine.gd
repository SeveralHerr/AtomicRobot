extends Node
class_name StateMachine

var states = {}
var current_state: State = null
var player: Player

func _init(player: Player) -> void:
	self.player = player

func add_state(name: String, state: State) -> void:
	states[name] = state

func change_state(name: String) -> void:
	#print(name)
	if current_state:
		current_state.exit_state(player)
	current_state = states[name]
	current_state.enter_state(player)

func handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(player, event)

func update(delta: float) -> void:
	if current_state:
		current_state.update(player, delta)
