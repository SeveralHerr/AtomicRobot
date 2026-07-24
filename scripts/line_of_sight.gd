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
		# target_position is LOCAL to this node, which inherits the parent Enemy's
		# transform — and _handle_direction() flips the enemy's scale.x to -1 when
		# facing left, which silently mirrors any local vector we set here. Using
		# to_local() on the desired world endpoint correctly inverts that (and any
		# other parent transform) instead of us having to guess/counteract the sign
		# by hand — which is what the old `* sign(get_parent().last_dir * -1)` was
		# attempting, backwards, and pointed the ray away from the player whenever
		# the enemy was facing left.
		var world_end: Vector2 = global_position + (player.global_position - global_position).normalized() * length
		target_position = to_local(world_end)

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
	# See _process() above: target_position is local and inherits the parent's
	# scale.x flip, so it must go through to_local() rather than being set from a
	# world-space direction directly.
	target_position = to_local(global_position + to_meter.normalized() * length)
	
	if is_colliding():
		var collider = get_collider()
		if collider.get_parent() is Meter:
			enabled = false
			return true

	enabled = false
	return false
