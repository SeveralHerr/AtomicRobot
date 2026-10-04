extends RefCounted
class_name EnemySeparation

## Same-lane enemies never physically collide with each other (collision_mask
## excludes the enemy layer, to avoid move_and_slide push jitter), so without an
## explicit separation nudge they can walk to/spawn at the same X and sit stacked
## on top of each other indefinitely. See docs/LANE_REFACTOR.md.

const DISTANCE := 40.0
const STRENGTH := 160.0


## Nudge `me` apart from other same-lane enemies within DISTANCE.
static func apply(me: Enemy, delta: float) -> void:
	if me.is_changing_lane or me.is_dead:
		return
	var push := push_for(me, me.get_tree().get_nodes_in_group("enemies"))
	if push != 0.0:
		# A direct position nudge rather than a velocity add — idle/attacking enemies
		# have their velocity.x actively damped to 0 by knockback friction every frame
		# (see EnemyKnockback.decay), which would eat a velocity-based push before
		# move_and_slide ever applied it.
		me.global_position.x += push * STRENGTH * delta


## Signed push strength (sum of 0..1 per close neighbour) away from the neighbours.
static func push_for(me: Enemy, others: Array) -> float:
	var push := 0.0
	for node in others:
		if node == me or not is_instance_valid(node) or not node is Enemy:
			continue
		var other: Enemy = node
		if other.lane != me.lane or other.is_changing_lane:
			continue
		# Corpses take up no space: a dying maid is on the floor for several seconds
		# and the living should be able to close over her, not shuffle around her.
		if other.is_dead:
			continue
		var dx: float = me.global_position.x - other.global_position.x
		var dist := absf(dx)
		if dist >= DISTANCE:
			continue
		# Perfectly overlapping (dx == 0) has no direction to push in — break the
		# tie deterministically so both instances agree on opposite directions.
		var dir := signf(dx) if dist > 0.5 else (1.0 if me.get_instance_id() > other.get_instance_id() else -1.0)
		push += dir * (DISTANCE - dist) / DISTANCE
	return push
