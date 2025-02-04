extends Sprite2D

@onready var visible_on_screen_notifier_2d: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


# Speed of the thrown sprite
var throw_speed = 300.0
var target_position = Vector2.ZERO
var direction = Vector2.ZERO
var lifetime: int = 4
var animation_time: int = 4

var player:Player
var timer: Timer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target_position = Globals.player.position
	
	# Calculate the direction to the target
	direction = (target_position - global_position).normalized()
	

	
	#visible_on_screen_notifier_2d.screen_exited.connect(queue_free)

	player = Globals.player

	move_towards_player()
	
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func move_towards_player():
	if not player:
		return

	# Animate using a Bezier interpolation
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position", player.global_position, animation_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_method(_arc_motion, 0.0, 1.0, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	#tween.tween_method(_bezier_interpolation.bind(player.global_position), 0.0, 1.0, 2.0)  # Move in 2 sec
	tween.play()

func _bezier_interpolation(t, player_position):
	var start = global_position
	var control = (global_position + player_position) / 2 + Vector2(0, -50)
	var end = player_position

	# Quadratic Bezier curve formula
	#global_position = (1-t)*(1-t) * start + 2*(1-t)*t * control + t*t * end




	#tween.play()

func _arc_motion(t):
	var start_pos = global_position
	var end_pos = player.global_position
	var arc_height = 5  # Adjust for a more dramatic curve

	# Increased curve factor (-10 instead of -4)
	var y_offset = -10 * arc_height * (t - 0.5) * (t - 0.5) + arc_height

	global_position.y = lerp(start_pos.y, end_pos.y, t) - y_offset


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Move the sprite in the direction of the player
	#position += direction * throw_speed * delta
		
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		var player: Player = body
		player.receive_hit(position, 1)
		queue_free()
		
	pass # Replace with function body.
