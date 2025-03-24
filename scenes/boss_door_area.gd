extends Area2D

var transition_layer: CanvasLayer
var transition_rect: ColorRect
var is_transitioning: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create transition elements
	setup_transition()

# Setup the transition canvas layer and color rect
func setup_transition() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 100  # Make sure it's on top of everything
	add_child(transition_layer)
	
	transition_rect = ColorRect.new()
	transition_rect.color = Color(0, 0, 0, 0)  # Start transparent
	transition_rect.size = get_viewport_rect().size
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	transition_layer.add_child(transition_rect)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_transitioning:
		handle_transition(delta)

# Handle the transition animation
func handle_transition(delta: float) -> void:
	var alpha = transition_rect.color.a
	if alpha < 1.0:
		# Fade to black
		alpha += delta * 2  # Adjust speed by changing multiplier
		transition_rect.color.a = min(alpha, 1.0)
	else:
		# Once fully black, change scene
		get_tree().change_scene_to_file("res://scenes/city_council_boss.tscn")
		is_transitioning = false

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_transitioning:
		is_transitioning = true
		transition_rect.color = Color(0, 0, 0, 0)  # Reset to transparent
