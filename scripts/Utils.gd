extends Node

const COIN_BULLET = preload("res://scenes/coin_bullet.tscn")
const HIT_FX = preload("res://scenes/hit_fx.tscn")

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
	
	
static func apply_hit_pause(node: Node2D, duration := 0.1):
	var time_passed := 0.0
	Engine.time_scale = 0.0
	
	while time_passed < duration:
		await node.get_tree().process_frame
		time_passed += 1.0 / ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	
	Engine.time_scale = 1.0

	
static func hit_effect(target: Node2D, hit_position: Vector2) -> void:
	var instance = HIT_FX.instantiate()
	target.add_child(instance)
	instance.global_position = hit_position
	instance.start()

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

## Coin throwing factory methods
static func throw_coin(spawn_position: Vector2, target_position: Vector2, parent_node: Node, use_arc: bool = false) -> void:
	var instance = COIN_BULLET.instantiate()
	parent_node.add_child(instance)
	var direction = (target_position - spawn_position).normalized()
	instance.start(spawn_position, direction, use_arc)

static func throw_coin_from_enemy(enemy: Node, use_arc: bool = false) -> void:
	if not enemy or not Globals.player:
		return
	var spawn_pos = enemy.global_position + enemy.coin_spawn_point.position
	var target_pos = Globals.player.enemy_attack_position.global_position
	throw_coin(spawn_pos, target_pos, enemy.player.get_parent(), use_arc)

static func throw_coin_delayed(enemy: Node, delay: float = 0.3, use_arc: bool = false) -> void:
	if not enemy:
		return
	await enemy.get_tree().create_timer(delay).timeout
	throw_coin_from_enemy(enemy, use_arc)
