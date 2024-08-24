extends RayCast2D
class_name LineOfSight


var raycast_distance = 110.0

func is_player_line_of_sight() -> bool:
	var to_player = Globals.player.global_position - global_position
	var distance = to_player.length()

	if distance > raycast_distance:
		#enabled = false
		return false

	#enabled = true
	target_position = to_player.normalized() * raycast_distance
	
	if is_colliding():
		var collider = get_collider()

		if collider is Player:
			#print("Player is in sight!")
			#enabled = false
			return true
			pass
			# Add your logic for when the player is in sight
		else:
			#print("Player is not in sight, something is blocking the view.")
			#enabled = false
			return false
			pass
	else:
		#enabled = false
		return false
		#print("Player is not in sight, out of range.")
		pass
