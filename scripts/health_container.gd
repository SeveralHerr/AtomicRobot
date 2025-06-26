extends HBoxContainer

@onready var player: Player = $"../../../../Player"

# Dynamic heart management
const HEART_SCENE = preload("res://scenes/hp_1.tscn")
var heart_instances: Array[Node] = []
var max_hearts: int = 0
var previous_health: int = 0
var is_initialized: bool = false

func _ready() -> void:
	player.player_health_updated.connect(_update_health)
	# Initialize with player's starting health (no animation)
	_update_health(player.health)
	is_initialized = true  # Mark as initialized after first update

func _update_health(current_health: int) -> void:
	print("Health updated to: ", current_health)
	
	# Check if health increased (heart pickup) and we're past initialization
	var health_gained = current_health > previous_health and is_initialized
	
	# Determine the maximum hearts we need (current health or existing max, whichever is higher)
	var needed_hearts = max(current_health, max_hearts)
	
	# Create additional heart instances if needed
	while heart_instances.size() < needed_hearts:
		_create_heart_instance()
	
	# Update visibility of all heart instances
	for i in range(heart_instances.size()):
		if i < current_health:
			heart_instances[i].show()
			# Apply pickup effect to newly gained hearts
			if health_gained and i >= previous_health:
				_play_heart_pickup_effect(heart_instances[i])
		else:
			heart_instances[i].hide()
	
	# Update previous health for next comparison
	previous_health = current_health

func _create_heart_instance() -> void:
	var heart_instance = HEART_SCENE.instantiate()
	add_child(heart_instance)
	heart_instances.append(heart_instance)
	max_hearts = heart_instances.size()
	print("Created heart instance. Total hearts: ", max_hearts)

func _play_heart_pickup_effect(heart_node: Node) -> void:
	# Create a pickup effect tween
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple tween properties
	
	# Store original values
	var original_scale = heart_node.scale
	var original_modulate = heart_node.modulate
	
	# Scale pulse effect
	tween.tween_property(heart_node, "scale", original_scale * 1.5, 0.2)
	tween.tween_property(heart_node, "scale", original_scale, 0.3).set_delay(0.2)
	
	# Color flash effect (bright white then back to normal)
	tween.tween_property(heart_node, "modulate", Color.WHITE, 0.1)
	tween.tween_property(heart_node, "modulate", original_modulate, 0.4).set_delay(0.1)
	
	# Optional: Slight rotation wobble
	tween.tween_property(heart_node, "rotation_degrees", 10.0, 0.1)
	tween.tween_property(heart_node, "rotation_degrees", -10.0, 0.2).set_delay(0.1)
	tween.tween_property(heart_node, "rotation_degrees", 0.0, 0.2).set_delay(0.3)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
