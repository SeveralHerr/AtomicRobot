extends Node

signal player_death
signal meter_maid_death
signal unlocked(name: String, description: String)
signal boss_fight(status: bool)

const DEFAULT_FRAMES = preload("res://Sprites/default_frames.tres")
const DEFAULT_NAME: String = "Cody"
const DEFAULT_DESCRIPTION: String = "Owner of Atomic Robot Tattoo"

const ROBOT_FRAMES = preload("res://Sprites/robot_frames.tres")
const ROBOT_NAME: String = "Atomic Robot"
const ROBOT_DESCRIPTION: String = "The official robot"

var selected_character: String

var unlockables = [
	Unlockable.new("Cody", "CODY IS NOW PLAYABLE", false),
	Unlockable.new("RYAN", "RYAN IS NOW PLAYABLE", false)
]

var cody_selected: bool = false
var player: Player
var player_last_position
var meters: Array
var meter_maids_killed: int = 0

var destroyed_nodes = {}

func mark_node_destroyed(node_name: String) -> void:
	destroyed_nodes[node_name] = true

func is_node_destroyed(node_name: String) -> bool:
	return destroyed_nodes.get(node_name, false)

func reset() -> void:
	cody_selected = false
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
