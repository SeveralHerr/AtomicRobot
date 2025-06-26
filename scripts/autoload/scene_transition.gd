extends CanvasLayer

signal transition_completed

func change_scene(target_scene: String) -> void:
	# Play the fade out animation
	$AnimationPlayer.play("fade_out")
	
	# Wait for the animation to finish
	await $AnimationPlayer.animation_finished
	
	# Change the scene
	get_tree().change_scene_to_file(target_scene)
	
	# Play the fade in animation
	$AnimationPlayer.play("fade_in")
	
	# Wait for the fade in to complete
	await $AnimationPlayer.animation_finished
	
	# Signal that the transition is complete
	transition_completed.emit()

func _ready() -> void:
	# Create the black overlay
	var overlay = ColorRect.new()
	overlay.color = Color.BLACK
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.name = "Overlay"
	overlay.modulate = Color(1, 1, 1, 0)  # Start transparent
	add_child(overlay)
	
	# Create the animation player
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)
	
	# Create fade_in animation
	var fade_in = Animation.new()
	var track_index = fade_in.add_track(Animation.TYPE_VALUE)
	fade_in.track_set_path(track_index, "Overlay:modulate")
	fade_in.track_insert_key(track_index, 0.0, Color(1, 1, 1, 1))  # Start opaque
	fade_in.track_insert_key(track_index, 0.5, Color(1, 1, 1, 0))  # End transparent
	fade_in.length = 0.5
	anim_player.add_animation("fade_in", fade_in)
	
	# Create fade_out animation
	var fade_out = Animation.new()
	track_index = fade_out.add_track(Animation.TYPE_VALUE)
	fade_out.track_set_path(track_index, "Overlay:modulate")
	fade_out.track_insert_key(track_index, 0.0, Color(1, 1, 1, 0))  # Start transparent
	fade_out.track_insert_key(track_index, 0.5, Color(1, 1, 1, 1))  # End opaque
	fade_out.length = 0.5
	anim_player.add_animation("fade_out", fade_out) 