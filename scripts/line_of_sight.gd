extends RayCast2D
class_name LineOfSight

var length 

func _ready() -> void:
	length = target_position.y

func is_player_line_of_sight() -> bool:
	var to_player = Globals.player.global_position - global_position
	var distance = to_player.length()
	target_position = to_player.normalized() * length
	
	if is_colliding():
		var collider = get_collider()
		if collider is Player:
			return true


	return false


func is_meter_line_of_sight(meter_position: Vector2) -> bool:
	enabled = true
	var to_meter = meter_position - global_position
	var distance = to_meter.length()
	target_position = to_meter.normalized() * length
	
	if is_colliding():
		var collider = get_collider()
		if collider.get_parent() is Meter:
			enabled = false
			return true

	enabled = false
	return false
