extends TextureRect

# Variables for tweaking
var sway_amount: float = 20.0  # How far the background sways
var sway_duration: float = 4.0  # Time it takes to complete one sway

func _ready():
	var tween = get_tree().create_tween()
	var initial_position = position

	# Sway to the right
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:x", initial_position.x + sway_amount, sway_duration )
	tween.tween_callback(sway_left)

func sway_left():
	var tween = get_tree().create_tween()
	var initial_position = position

	# Sway back to the left
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:x", initial_position.x - sway_amount * 2, sway_duration)
	tween.tween_callback(sway_right)

func sway_right():
	var tween = get_tree().create_tween()
	var initial_position = position

	# Sway back to the right
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:x", initial_position.x + sway_amount * 2, sway_duration)
	tween.tween_callback( sway_left)
