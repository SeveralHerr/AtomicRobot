extends Node2D
class_name LeafManager

signal leaf_interaction(leaf: DroppedLeaf, interaction_type: String)

@export var spawn_distance: float = 400.0
@export var despawn_distance: float = 500.0 
@export var leaf_density: float = 1  # leaves per pixel
@export var ground_y_offset: float = 0  # offset from ground level
@export var leaf_pool_size: int = 100
@export var max_active_leaves: int = 280

@onready var player: Player = $"../Player"

var leaf_pool: Array[DroppedLeaf] = []
var active_leaves: Array[DroppedLeaf] = []
var camera: Camera2D
var last_spawn_x: float = 0.0
var leaf_scene = preload("res://scenes/leaf.tscn")
const LEAF_2 = preload("res://scenes/leaf2.tscn")

# Clump-based spawning
var min_clump_spacing: float = 40.0  # Minimum distance between clumps
var max_clump_spacing: float = 200.0  # Maximum distance between clumps
var clump_size_min: int = 2  # Minimum leaves per clump
var clump_size_max: int = 8  # Maximum leaves per clump
var clump_radius: float = 40.0  # How spread out leaves are within a clump

func _ready() -> void:
	# Find player
	#await get_tree().process_frame  # Wait for scene to be ready
	#player = get_tree().get_first_node_in_group("player")
	
	if player:
		camera = player.get_node("Camera2D") if player.has_node("Camera2D") else null
		last_spawn_x = player.global_position.x
		setup_leaf_pool()
		

		Globals.gust.connect(_on_gust)
	else:
		print("LeafManager: Could not find player!")


#func find_node_by_class(node: Node, target_class) -> Node:
	#if node.get_class() == target_class.get_class() or node is target_class:
		#return node
	#
	#for child in node.get_children():
		#var result = find_node_by_class(child, target_class)
		#if result:
			#return result
	#return null

func setup_leaf_pool() -> void:
	for i in range(leaf_pool_size):
		var leaf = leaf_scene.instantiate() as DroppedLeaf
		leaf.set_physics_process(false)
		leaf.visible = false
		add_child(leaf)
		leaf_pool.append(leaf)

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
			
		var leaf = leaf_pool.pop_back()
		if not leaf:
			continue
		
		# Random position within clump radius
		var angle = randf() * TAU
		var distance = randf() * clump_radius
		
		var spawn_x = center_x + cos(angle) * distance
		var spawn_y = base_y + sin(angle) * distance * 0.3  # Less vertical spread
		
		# Ensure leaf stays on ground
		spawn_y = max(spawn_y, get_ground_level(spawn_x) + ground_y_offset)
		
		leaf.activate_from_pool(Vector2(spawn_x, spawn_y))
		
		# Add some random initial velocity
		leaf.linear_velocity = Vector2(randf_range(-5, 5), 0)
		leaf.angular_velocity = randf_range(-0.5, 0.5)
		
		active_leaves.append(leaf)

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
