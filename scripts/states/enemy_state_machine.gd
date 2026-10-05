extends Node
class_name EnemyStateMachine

var states = {}
var current_state: EnemyState = null
var enemy: Enemy

func _init(e: Enemy) -> void:
	enemy = e


func add_state(name: String, state: EnemyState) -> void:
	states[name] = state


## States live only in `states`, never in the tree, so the tree's own cleanup
## never reaches them: free them with the machine or each enemy leaks its states.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for s in states.values():
			if is_instance_valid(s):
				s.free()
		states.clear()

func change_state(name: String) -> void:
	if current_state is DeadEnemyState:
		return

	if not states.has(name):
		push_error("EnemyStateMachine: no state '%s' registered on %s (have: %s)"
			% [name, enemy.name if is_instance_valid(enemy) else "<freed>", ", ".join(states.keys())])
		return

	# Re-entering the state we are already in is always a caller bug — it comes
	# from a per-frame `change_state` poll (the window maid did exactly this).
	# Running exit/enter again would replay every enter-time effect once per
	# frame: restarting the attack animation before it ever reaches its hit
	# frame, and churning the frame_changed connection. States that need to
	# genuinely re-run an action expose their own re-arm path instead.
	if states[name] == current_state:
		return

	print("Enemy state", name)
	if current_state:
		current_state.exit_state()

	current_state = states[name]

	current_state.enter_state()


func update(delta: float) -> void:
	if current_state:
		current_state.update( delta)
		
