extends Control
@onready var story_label_1: Label = $CenterContainer/StoryLabel1
@onready var story_label_2: Label = $CenterContainer/StoryLabel2
@onready var story_label_3: Label = $CenterContainer/StoryLabel3
@onready var story_label_4: Label = $CenterContainer/StoryLabel4
@onready var story_label_5: Label = $CenterContainer/StoryLabel5
@onready var story_label_6: Label = $CenterContainer/StoryLabel6
@onready var continue_label: Label = $MarginContainer/ContinueLabel

const GAME: PackedScene = preload("res://scenes/new_asset_test.tscn")
var current_label_index: int = 0
var labels: Array[Label]
var can_proceed: bool = false
var current_tween: Tween

func _ready() -> void:
	# Initialize labels array
	labels = [story_label_1, story_label_2, story_label_3, story_label_4, story_label_5, story_label_6]
	
	# Hide all labels initially and set their modulate alpha to 0
	for label in labels:
		label.show()
		label.modulate.a = 0
	
	continue_label.show()
	continue_label.modulate.a = 0
	
	# Start the story sequence
	show_next_label()

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed and can_proceed:
			if current_label_index < labels.size():
				show_next_label()
			else:
				get_tree().change_scene_to_packed(GAME)

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
