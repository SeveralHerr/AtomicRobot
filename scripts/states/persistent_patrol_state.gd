extends PatrolState
class_name PersistentPatrolState

## Patrol state for persistent meter maids with different chase triggers

func _should_chase_player() -> bool:
	var dist = enemy.position.distance_to(Globals.player.position)
	
	# Persistent enemies have extended range detection
	if dist < 250:
		return true
		
	# Still respond to close range
	if dist < 50:
		return true
		
	return false