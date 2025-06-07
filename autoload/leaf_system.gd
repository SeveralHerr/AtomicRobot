extends Node

var leaf_manager: LeafManager

func _ready():
	# Auto-create leaf manager for current scene
	setup_leaf_manager()

func setup_leaf_manager():
	# Check if leaf manager already exists
	leaf_manager = get_tree().get_first_node_in_group("leaf_manager")


# Global interaction methods that other scripts can call
func trigger_sword_swing(position: Vector2, range: float = 100.0):
	if leaf_manager:
		leaf_manager._on_gust(position, range)

func trigger_car_gust(car_position: Vector2, car_velocity: Vector2, gust_range: float = 150.0):
	if leaf_manager:
		leaf_manager.trigger_car_gust(car_position, car_velocity, gust_range)

func trigger_area_gust(center: Vector2, radius: float, power: float):
	if leaf_manager:
		leaf_manager.trigger_area_gust(center, radius, power)

func get_leaf_debug_info() -> Dictionary:
	if leaf_manager:
		return leaf_manager.get_debug_info()
	return {}
