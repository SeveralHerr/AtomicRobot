extends ChasePlayerState
class_name PersistentChaseState

## Chase state for persistent meter maids with different patrol return logic

func _should_return_to_patrol() -> bool:
	var dist = enemy.position.distance_to(Globals.player.position)
	
	# Persistent enemies only return to patrol when very far
	if dist > 250:
		return true
		
	return false