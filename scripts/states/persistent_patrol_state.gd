extends PatrolState
class_name PersistentPatrolState

## Patrol state for persistent meter maids with different chase triggers

func _should_chase_player() -> bool:
	# Use squared distance for better performance
	var dist_squared = enemy.position.distance_squared_to(Globals.player.position)
	
	# Persistent enemies have extended range detection (250^2 = 62500)
	# Close range is also included (50^2 = 2500)
	return dist_squared < 62500