extends LaneProjectile
class_name FireballBullet

## Payton's fireball. Same ranged trade as Cass's flip-flop (speed, slide-back), but it
## flies flat and flickers through its 8 flame frames instead of spinning. The art
## points right, so it mirrors when thrown left.

## Seconds the flame takes to burn out at the end of its range, and how far it drifts on.
const FIZZLE_TIME := 0.12
const FIZZLE_DRIFT := 18.0

@onready var sprite: AnimatedSprite2D = $Sprite


func _init() -> void:
	speed = FlipflopBullet.FLIPFLOP_SPEED
	knockback = FlipflopBullet.KNOCKBACK


func _aimed() -> void:
	if dir != 0:
		scale.x = -1.0 if dir < 0 else 1.0


## Burns out instead of blinking off: stops flying (no more hit sweeps), shrinks, fades.
func _expire() -> void:
	var drift: float = position.x + dir * FIZZLE_DRIFT
	set_physics_process(false)
	var t := create_tween().set_parallel()
	t.tween_property(self, "position:x", drift, FIZZLE_TIME)
	t.tween_property(sprite, "scale", Vector2(0.4, 0.4), FIZZLE_TIME)
	t.tween_property(sprite, "modulate:a", 0.0, FIZZLE_TIME)
	t.chain().tween_callback(queue_free)


## On a hit the flame bursts where it struck (a puff that swells and fades), so the
## shot reads as fire rather than blinking out under the generic spark.
func _hit(enemy: Enemy) -> void:
	var puff := AnimatedSprite2D.new()
	puff.sprite_frames = sprite.sprite_frames
	puff.play(sprite.animation)
	puff.global_position = sprite.global_position
	puff.scale = Vector2(scale.x, 1.0)
	puff.z_index = z_index
	get_parent().add_child(puff)
	var t := puff.create_tween().set_parallel()
	t.tween_property(puff, "scale", Vector2(scale.x * 1.7, 1.7), FIZZLE_TIME)
	t.tween_property(puff, "modulate:a", 0.0, FIZZLE_TIME)
	t.chain().tween_callback(puff.queue_free)
	super._hit(enemy)
