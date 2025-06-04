extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

static func shake_node2d(node: Node2D, strength: float = 10.0, duration: float = 0.3, frequency: float = 0.02) -> void:
	var original_pos = node.position
	var tween = node.get_tree().create_tween()
	var steps = int(duration / frequency)
	for i in range(steps):
		var random_offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		tween.tween_property(node, "position", original_pos + random_offset, frequency)
	# Ensure the last tween resets to the original position
	tween.tween_property(node, "position", original_pos, frequency)

static func shake_two_node2d(node1: Node2D, node2: Node2D, strength1: float = 10.0, duration1: float = 0.3, strength2: float = 10.0, duration2: float = 0.3, frequency: float = 0.02) -> void:
	var original_pos1 = node1.position
	var original_pos2 = node2.position
	var tween1 = node1.get_tree().create_tween()
	var tween2 = node2.get_tree().create_tween()
	var steps = int(min(duration1, duration2) / frequency)
	for i in range(steps):
		var base_offset = Vector2(
			randf_range(-1, 1),
			randf_range(-1, 1)
		)
		var offset1 = base_offset * strength1
		var offset2 = base_offset * strength2
		tween1.tween_property(node1, "position", original_pos1 + offset1, frequency)
		tween2.tween_property(node2, "position", original_pos2 + offset2, frequency)
	# Ensure the last tween resets to the original position
	tween1.tween_property(node1, "position", original_pos1, frequency)
	tween2.tween_property(node2, "position", original_pos2, frequency)
