extends HBoxContainer

@onready var player: Player = $"../../../../Player"

# Dynamic heart management
const HEART_SCENE = preload("res://scenes/hp_1.tscn")
## Damage stages for a single orb, indexed by (hits left - 1): the atom sheds an
## orbit per hit. Player.HITS_PER_ORB must stay equal to this array's size.
const ORB_TEXTURES: Array[Texture2D] = [
	preload("res://images/Logo+Web-3.png"),  # 1 hit left
	preload("res://images/Logo+Web-2.png"),  # 2 hits left
	preload("res://images/Logo+Web.png"),    # 3 hits left (untouched)
]
var heart_instances: Array[Node] = []
var max_hearts: int = 0
var previous_health: int = 0
var is_initialized: bool = false

func _ready() -> void:
	player.player_health_updated.connect(_update_health)
	# Initialize with player's starting health (no animation)
	_update_health(player.health)
	is_initialized = true  # Mark as initialized after first update

## `current_health` is raw hit points. Each orb soaks Player.HITS_PER_ORB of them, so
## a hit usually re-textures the rightmost orb rather than removing one.
func _update_health(current_health: int) -> void:
	var orbs := Player.orbs_for(current_health)
	print("Health updated to: ", current_health, " (", orbs, " orbs)")

	# Check if health increased (heart pickup) and we're past initialization
	var health_gained = current_health > previous_health and is_initialized
	var previous_orbs := Player.orbs_for(previous_health)

	# Determine the maximum orbs we need (current orbs or existing max, whichever is higher)
	var needed_hearts = max(orbs, max_hearts)

	# Create additional heart instances if needed
	while heart_instances.size() < needed_hearts:
		_create_heart_instance()

	# Re-texture and show every orb that still has hits left; hide the spent ones
	for i in range(heart_instances.size()):
		var orb := heart_instances[i] as TextureRect
		var hits_left := Player.orb_hits_left(i, current_health)
		if hits_left <= 0:
			orb.hide()
			continue
		orb.texture = ORB_TEXTURES[hits_left - 1]
		orb.show()
		# Apply pickup effect to newly gained orbs
		if health_gained and i >= previous_orbs:
			_play_heart_pickup_effect(orb)

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
	
	# # Optional: Slight rotation wobble
	# tween.tween_property(heart_node, "rotation_degrees", 10.0, 0.1)
	# tween.tween_property(heart_node, "rotation_degrees", -10.0, 0.2).set_delay(0.1)
	# tween.tween_property(heart_node, "rotation_degrees", 0.0, 0.2).set_delay(0.3)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
