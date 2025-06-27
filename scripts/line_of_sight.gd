extends RayCast2D
class_name LineOfSight

var length
var player: Player
var is_meter: bool = false

func _ready() -> void:
	length = target_position.y
	player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if player and not is_meter:
		var to_player = player.global_position - global_position
		target_position = to_player.normalized() * length * sign(get_parent().last_dir * -1)

func is_player_line_of_sight() -> bool:
	if not player:
		return false

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
