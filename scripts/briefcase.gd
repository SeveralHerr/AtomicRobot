extends RigidBody2D
class_name Briefcase

@onready var visible_on_screen_notifier_2d: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

const HIT_FX = preload("res://scenes/hit_fx.tscn")

var _direction: Vector2 = Vector2.LEFT

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var start_pos = global_position
	var target_pos = Globals.player.global_position

	# Calculate the distance and height difference
	var distance_x = target_pos.x - start_pos.x
	var distance_y = target_pos.y - start_pos.y

	# Determine the time it should take for the projectile to reach the player
	var time_to_target = 1  # Adjust this to control the arc height and duration

	# Calculate the horizontal velocity required to reach the player in the given time
	var velocity_x = distance_x / time_to_target

	# Calculate the vertical velocity required to reach the player's height considering gravity
	var gravity = 20.0  # Adjust this to change the arc's shape
	var velocity_y = (distance_y + 1 * gravity * pow(time_to_target, 2)) / time_to_target


	#var direction = (Globals.player.global_position - global_position).normalized() * Vector2(1, -1)
	linear_velocity  = Vector2(velocity_x, -velocity_y)


func _on_despawn_timer_timeout() -> void:
	queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Briefcase or body is Enemy:
		return

	if body is Player:
		body.receive_hit(global_position, 1)
		var instance = HIT_FX.instantiate()
		body.get_tree().root.add_child(instance)
		instance.global_position = global_position
		instance.start()
		queue_free()
