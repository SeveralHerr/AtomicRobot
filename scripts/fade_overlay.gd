extends ColorRect
class_name FadeOverlay



func _ready() -> void:
	hide()
	color = Color(0, 0, 0, 0) # Start fully transparent
	# Start fully black
	#color.a = 1.0
	#color = Color(0, 0, 0, 0)
	# Fade in when the scene starts
	#fade_in()

func fade_in(duration: float = 1.0) -> void:
	show()
	color = Color(0, 0, 0, 1)
	var tween = create_tween()
	tween.tween_property(self, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(duration).timeout
	return

func fade_out(duration: float = 1.0) -> void:
	show()
	color = Color(0, 0, 0, 0)
	var tween = create_tween()
	tween.tween_property(self, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(duration).timeout
	return
