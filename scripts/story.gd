extends Control
@onready var story_label_1: Label = $CenterContainer/StoryLabel1

@onready var continue_label: Label = $MarginContainer/ContinueLabel

const CONTROLS_SPLASH: PackedScene = preload("res://scenes/controls_splash.tscn")
const AnyButton := preload("res://scripts/any_button.gd")
var current_label_index: int = 0
var labels: Array[Label]
var can_proceed: bool = false
var current_tween: Tween

func _ready() -> void:
	# Initialize labels array
	labels = [story_label_1]
	
	# Hide all labels initially and set their modulate alpha to 0
	for label in labels:
		label.show()
		label.modulate.a = 0

	continue_label.show()
	continue_label.modulate.a = 0
	
	# Wait for initial fade in to complete before starting story
	#await fade_overlay.fade_finished
	show_next_label()

func _input(event: InputEvent) -> void:
	if can_proceed and AnyButton.is_press(event):
		if current_label_index < labels.size():
			show_next_label()
		else:
			transition_to_game()

func transition_to_game() -> void:
	can_proceed = false
	
	# Fade out all labels and continue text
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	
	# Fade out continue label
	current_tween.tween_property(continue_label, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Fade out current label if any
	if current_label_index > 0:
		current_tween.parallel().tween_property(labels[current_label_index - 1], "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await current_tween.finished

	# Change scene
	get_tree().change_scene_to_packed(CONTROLS_SPLASH)

func show_next_label() -> void:
	if current_label_index < labels.size():
		can_proceed = false
		
		# Create parallel tweens for fading out
		if current_tween:
			current_tween.kill()
		
		current_tween = create_tween()
		
		# Fade out continue label
		current_tween.tween_property(continue_label, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		# If not first label, fade out previous label in parallel
		if current_label_index > 0:
			current_tween.parallel().tween_property(labels[current_label_index - 1], "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		await current_tween.finished
		
		# Fade in current label
		await fade_in(labels[current_label_index])
		
		# Wait for 0.2 seconds before allowing input
		await get_tree().create_timer(0.2).timeout
		
		# Fade in continue label
		await fade_in(continue_label)
		
		can_proceed = true
		current_label_index += 1

func fade_in(label: Label) -> void:
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.tween_property(label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await current_tween.finished

func fade_out(label: Label) -> void:
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.tween_property(label, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await current_tween.finished
