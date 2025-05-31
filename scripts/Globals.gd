extends Node

signal player_death
signal meter_maid_death
signal meter_maid_boss_death
signal unlocked(name: String, description: String)
signal boss_fight(status: bool)

var selected_character: String = "Cody"
var character_dict = {
		"Robot": Unlockable.new("Robot", "ROBOT IS NOW PLAYABLE", true, "Atomic Robot Tattoo Mascot", preload("res://sprites/cody_sprite_frames.tres"), ""),
		"Cody": Unlockable.new("Cody", "CODY IS NOW PLAYABLE", true, "Owner of Atomic Robot Tattoo", preload("res://Sprites/cody_sprite_frames.tres"), ""),
		"Ryan": Unlockable.new("Ryan", "RYAN IS NOW PLAYABLE", true, "Employee of Atomic Robot Tatoo", preload("res://Sprites/cody_sprite_frames.tres"), ""),
	}

var player: Player
var player_last_position
var meters: Array
var meter_maids_killed: int = 0
var meter_maid_boss_killed: int = 0

var destroyed_nodes = {}

#func _ready() -> void:
	#player = get_tree().get_first_node_in_group("Player")

func mark_node_destroyed(node_name: String) -> void:
	destroyed_nodes[node_name] = true

func is_node_destroyed(node_name: String) -> bool:
	return destroyed_nodes.get(node_name, false)

func reset() -> void:
	selected_character = "Robot"
	meters.clear()
	meter_maids_killed = 0
	player_last_position = null
	

func nearest_meter(pos: Vector2) -> Node2D:
	var lowest_distance = 32323  
	var nearest_meter: Node2D = null 

	for meter in meters:
		var dist = pos.distance_to(meter.position) 
		if dist < lowest_distance:
			lowest_distance = dist
			nearest_meter = meter  

	return nearest_meter
