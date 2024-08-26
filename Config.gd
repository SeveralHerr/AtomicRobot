extends Node

signal player_death

var cody_unlocked: bool = false
var cody_selected: bool = false
var player: Player
var player_last_position
var meters: Array

var destroyed_nodes = {}

func mark_node_destroyed(node_name: String) -> void:
	destroyed_nodes[node_name] = true

func is_node_destroyed(node_name: String) -> bool:
	return destroyed_nodes.get(node_name, false)

func reset() -> void:
	cody_selected = false
	meters.clear()
	

func nearest_meter(pos: Vector2) -> Node2D:
	var lowest_distance = 32323  
	var nearest_meter: Node2D = null 

	for meter in meters:
		var dist = pos.distance_to(meter.position) 
		if dist < lowest_distance:
			lowest_distance = dist
			nearest_meter = meter  

	return nearest_meter
