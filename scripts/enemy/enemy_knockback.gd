extends RefCounted
class_name EnemyKnockback

## Knockback for an Enemy: the shove a blow gives it, and how that shove bleeds back
## into (and out of) its horizontal velocity frame by frame. The shove itself lives in
## Enemy.knockback_velocity because states read it to hold off steering mid-flight.

const HOP_VELOCITY := -50.0
## Horizontal friction once the shove is spent (px/s^2).
const FRICTION := 300.0
## Below this |knockback_velocity.x| the shove counts as spent and friction applies.
const SPENT_BELOW := 10.0


## Knock `e` away from `from` (the attacker's world position), or — when there is no
## attacker to read, e.g. a hazard with no player resolved — backwards off its own facing.
static func apply(e: Enemy, strength: float, from: Variant = null) -> void:
	var direction := Vector2(-e.facing, 0.0)
	if from != null:
		direction = (e.global_position - (from as Vector2)).normalized()
	e.knockback_velocity = direction * strength
	e.velocity.y = HOP_VELOCITY


## One physics step: feed the shove into velocity.x, decay it, and damp velocity.x
## once it's spent (states that steer set velocity.x themselves every frame).
static func decay(e: Enemy, delta: float) -> void:
	e.velocity.x += e.knockback_velocity.x * delta
	e.knockback_velocity = e.knockback_velocity.move_toward(Vector2.ZERO, e.knockback_decay * delta * 100)
	if abs(e.knockback_velocity.x) < SPENT_BELOW:
		e.velocity.x = move_toward(e.velocity.x, 0.0, FRICTION * delta)
