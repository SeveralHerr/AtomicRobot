extends Node
class_name EnemyFactory

## Factory for creating different enemy types using the new component system
## Simplifies enemy creation and reduces boilerplate

# Preloaded scenes - will be set up later when scene exists
static var enemy_scene: PackedScene = null

## Create an enemy of the specified type at the given position
static func create_enemy(type: String, position: Vector2, parent: Node = null):
	# Load scene dynamically to avoid circular dependencies
	if not enemy_scene:
		enemy_scene = load("res://scenes/enemy.tscn")  # Use existing scene for now
	
	var enemy = enemy_scene.instantiate()
	
	# Set configuration using the old approach for compatibility
	if enemy.has_method("_setup_initial_state"):
		enemy._setup_initial_state()
	
	enemy.global_position = position
	
	# Add to scene if parent provided
	if parent:
		parent.add_child(enemy)
	
	return enemy

## Create multiple enemies from data
static func create_enemies_from_data(enemy_data: Array, parent: Node) -> Array:
	var enemies: Array = []
	
	for data in enemy_data:
		if data.has("type") and data.has("position"):
			var enemy = create_enemy(data.type, data.position, parent)
			enemies.append(enemy)
	
	return enemies

## Helper methods for common enemy creation patterns

static func create_patrol_meter_maid(position: Vector2, parent: Node = null):
	return create_enemy("patrol_meter_maid", position, parent)

static func create_ranged_meter_maid(position: Vector2, parent: Node = null):
	return create_enemy("ranged_meter_maid", position, parent)

static func create_melee_meter_maid(position: Vector2, parent: Node = null):
	return create_enemy("melee_meter_maid", position, parent)

static func create_window_meter_maid(position: Vector2, parent: Node = null):
	return create_enemy("window_meter_maid", position, parent)

## Legacy compatibility - can be used to replace old spawning code
static func spawn_meter_maid_at_position(position: Vector2, parent: Node):
	# Default to patrol type for backwards compatibility
	return create_patrol_meter_maid(position, parent)
