extends Node
class_name StateMachine

var states = {}
var current_state: State = null
var previous_state: State = null
var player: Player

func _init(player: Player) -> void:
	self.player = player

func add_state(name: String, state: State) -> void:
	states[name] = state


## States live only in `states`, never in the tree, so the tree's own cleanup
## never reaches them: free them with the machine or each Player leaks its states.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for s in states.values():
			if is_instance_valid(s):
				s.free()
		states.clear()

func change_state(name: String) -> void:
	#print(name)
	if current_state:
		previous_state = current_state
		current_state.exit_state(player)

	current_state = states[name]
	#print("Player state: ", name)
	current_state.enter_state(player)

func handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(player, event)

func update(delta: float) -> void:
	if current_state:
		current_state.update(player, delta)
		
func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(player, delta)
