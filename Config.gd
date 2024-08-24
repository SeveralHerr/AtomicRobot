extends Node

signal player_death

var cody_unlocked: bool = false
var cody_selected: bool = false
var player: Player
var meters: Array

func nearest_meter(pos: Vector2) -> Node2D:
	var lowest_distance = 32323  
	var nearest_meter: Node2D = null 

	for meter in meters:
		var dist = pos.distance_to(meter.position) 
		if dist < lowest_distance:
			lowest_distance = dist
			nearest_meter = meter  

	return nearest_meter
