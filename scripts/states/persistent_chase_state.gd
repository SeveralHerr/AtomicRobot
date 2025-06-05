extends ChasePlayerState
class_name PersistentChaseState

## Chase state for persistent meter maids with different patrol return logic

func _should_return_to_patrol() -> bool:
	# Use squared distance for better performance (250^2 = 62500)
	var dist_squared = enemy.position.distance_squared_to(Globals.player.position)
	
	# Persistent enemies only return to patrol when very far
	return dist_squared > 62500