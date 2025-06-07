extends Node2D
class_name LeafManager

signal leaf_interaction(leaf: DroppedLeaf, interaction_type: String)

@export var spawn_distance: float = 500.0
@export var despawn_distance: float = 600.0 
@export var leaf_density: float = 1  # leaves per pixel
@export var ground_y_offset: float = 0  # offset from ground level
@export var leaf_pool_size: int = 100
@export var max_active_leaves: int = 280

@onready var player: Player = $"../Player"

var ground_y = -1
var leaf_pool: Array[DroppedLeaf] = []
var active_leaves: Array[DroppedLeaf] = []
var camera: Camera2D
var last_spawn_x: float = 0.0
var leaf_scene = preload("res://scenes/leaf.tscn")
const LEAF_2 = preload("res://scenes/leaf2.tscn")
const PAPER = preload("res://scenes/paper.tscn")

# Spawn probability weights (higher = more common)
var debris_types: Array[Dictionary] = [
	{"scene": leaf_scene, "weight": 50.0, "name": "leaf1"},
	{"scene": LEAF_2, "weight": 25.0, "name": "leaf2"},  # Half as common as leaf1
	{"scene": PAPER, "weight": 10.0, "name": "paper"}    # Less common than leaves
]
# Clump-based spawning
var min_clump_spacing: float = 60.0  # Minimum distance between clumps
var max_clump_spacing: float = 200.0  # Maximum distance between clumps
var clump_size_min: int = 2  # Minimum leaves per clump
var clump_size_max: int = 9  # Maximum leaves per clump
var clump_radius: float = 30.0  # How spread out leaves are within a clump

func _ready() -> void:
	if player:
		camera = player.get_node("Camera2D") if player.has_node("Camera2D") else null
		last_spawn_x = player.global_position.x
		setup_leaf_pool()
		

		Globals.gust.connect(_on_gust)
	else:
		print("LeafManager: Could not find player!")

func get_random_debris_type() -> Dictionary:
	# Calculate total weight
	var total_weight = 0.0
	for debris_type in debris_types:
		total_weight += debris_type.weight
	
	# Pick random value in weight range
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	# Find which debris type this random value corresponds to
	for debris_type in debris_types:
		current_weight += debris_type.weight
		if random_value <= current_weight:
			return debris_type
	
	# Fallback to first type
	return debris_types[0]

func setup_leaf_pool() -> void:
	# Create pool with mixed debris types based on weights
	for i in range(leaf_pool_size):
		var selected_debris = get_random_debris_type()
		var debris = selected_debris.scene.instantiate() as DroppedLeaf
		debris.set_physics_process(false)
		debris.visible = false
		add_child(debris)
		leaf_pool.append(debris)

func _process(delta: float) -> void:
	if not player:
		return
		
	# Spawn leaves around player
	spawn_leaves_around_player()
	
	# Clean up distant leaves
	cleanup_distant_leaves()
	
	# Limit active leaves for performance
	limit_active_leaves()

func spawn_leaves_around_player() -> void:
	if leaf_pool.size() == 0:
		return
	
	var player_x = player.global_position.x
	var spawn_left = player_x - spawn_distance
	var spawn_right = player_x + spawn_distance
	
	# Generate potential clump positions with random spacing
	var current_x = spawn_left
	while current_x < spawn_right:
		if leaf_pool.size() == 0:
			break
			
		# Check if there's already a clump near this position
		if not has_clump_nearby(current_x):
			spawn_leaf_clump(current_x)
		
		# Random spacing to next potential clump
		var next_spacing = randf_range(min_clump_spacing, max_clump_spacing)
		current_x += next_spacing

func has_clump_nearby(x_position: float) -> bool:
	var min_distance = min_clump_spacing * 0.7  # Allow some overlap
	
	for leaf in active_leaves:
		if abs(leaf.global_position.x - x_position) < min_distance:
			return true
	return false

func spawn_leaf_clump(center_x: float) -> void:
	var clump_size = randi_range(clump_size_min, clump_size_max)
	var base_y = get_ground_level(center_x) + ground_y_offset
	
	for i in range(clump_size):
		if leaf_pool.size() == 0:
			break
			
		var debris = leaf_pool.pop_back()
		if not debris:
			continue
		
		# Random position within clump radius
		var angle = randf() * TAU
		var distance = randf() * clump_radius
		
		var spawn_x = center_x + cos(angle) * distance
		var spawn_y = base_y + sin(angle) * distance * 0.3  # Less vertical spread
		
		# Ensure debris stays on ground
		spawn_y = ground_y
		
		debris.activate_from_pool(Vector2(spawn_x, spawn_y))
		
		# Add some random initial velocity
		debris.linear_velocity = Vector2(randf_range(-5, 5), 0)
		debris.angular_velocity = randf_range(-0.5, 0.5)
		
		active_leaves.append(debris)

func get_ground_level(x: float) -> float:
	# Simple ground detection - you may need to adjust this based on your level
	# This assumes a relatively flat ground level
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		Vector2(x, -1000),  # Start high above
		Vector2(x, 1000),   # End low below
		2  # Ground collision layer
	)
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y
	
	# Fallback to player's Y position if no ground found
	return player.global_position.y if player else 0

func cleanup_distant_leaves() -> void:
	if not player:
		return
		
	var player_pos = player.global_position
	var leaves_to_remove: Array[DroppedLeaf] = []
	
	for leaf in active_leaves:
		if leaf.global_position.distance_to(player_pos) > despawn_distance:
			leaves_to_remove.append(leaf)
	
	for leaf in leaves_to_remove:
		return_leaf_to_pool(leaf)
	
	# No need for region cleanup in simplified system

func limit_active_leaves() -> void:
	while active_leaves.size() > max_active_leaves:
		# Remove the leaf farthest from player
		var farthest_leaf: DroppedLeaf = null
		var max_distance: float = 0
		
		for leaf in active_leaves:
			var distance = leaf.global_position.distance_to(player.global_position)
			if distance > max_distance:
				max_distance = distance
				farthest_leaf = leaf
		
		if farthest_leaf:
			return_leaf_to_pool(farthest_leaf)

func return_leaf_to_pool(leaf: DroppedLeaf) -> void:
	if leaf in active_leaves:
		active_leaves.erase(leaf)
		leaf.reset_for_pool()
		leaf_pool.append(leaf)

# Interaction system
func _on_gust(source_position: Vector2, attack_range: float) -> void:
	for leaf in active_leaves:
		if leaf.global_position.distance_to(source_position) <= attack_range:
			leaf.do_gust(13.0, source_position)
			leaf_interaction.emit(leaf, "sword_swing")

func trigger_car_gust(car_position: Vector2, car_velocity: Vector2, gust_range: float = 150.0) -> void:
	var gust_power = car_velocity.length() * 0.01  # Scale with car speed
	
	for leaf in active_leaves:
		var distance = leaf.global_position.distance_to(car_position)
		if distance <= gust_range:
			# Power decreases with distance
			var adjusted_power = gust_power * (1.0 - distance / gust_range)
			leaf.do_gust(adjusted_power, car_position)
			leaf_interaction.emit(leaf, "car_gust")

func trigger_area_gust(center: Vector2, radius: float, power: float) -> void:
	for leaf in active_leaves:
		if leaf.global_position.distance_to(center) <= radius:
			leaf.do_gust(power, center)
			leaf_interaction.emit(leaf, "area_gust")

# Debug info
func get_debug_info() -> Dictionary:
	return {
		"active_leaves": active_leaves.size(),
		"pooled_leaves": leaf_pool.size(),
		"player_position": player.global_position if player else Vector2.ZERO,
		"spawn_range": str(player.global_position.x - spawn_distance) + " to " + str(player.global_position.x + spawn_distance) if player else "No player"
	}
