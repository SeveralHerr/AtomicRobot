extends LaneProjectile
class_name FlipflopBullet

## Cass's thrown flip-flop. Ranged fighters trade melee safety for damage, so the
## shot has to keep a charging maid at range: it flies faster than Robot's bullet
## and smacks the target back hard enough that she must close the gap again.

const SPIN_DEGREES_PER_SEC: float = 600.0
## 1.5x Robot's bullet: crosses the 220 px reach in ~0.24 s.
const FLIPFLOP_SPEED: float = 900.0
## A melee blow shoves 200 (Enemy.receive_hit); this one ~doubles the slide-back (480 tested worse: 3/4 bot wins vs 4/4).
const KNOCKBACK: float = 380.0
## Seconds a spent flip-flop takes to tumble out (max range) or ricochet off a hit.
const TUMBLE_TIME: float = 0.18


func _init() -> void:
	speed = FLIPFLOP_SPEED
	knockback = KNOCKBACK


## Overhand throw: the top tips forward, so it spins clockwise flying right and
## counter-clockwise flying left (always clockwise read as backspin on a left throw).
func _spin(delta: float) -> void:
	rotation_degrees += signf(dir) * SPIN_DEGREES_PER_SEC * delta



## Out of range it drops out of the air, still spinning, instead of blinking off.
func _expire() -> void:
	var fly_dir: int = dir
	set_physics_process(false)  # no more flight or hit sweeps
	var t := create_tween().set_parallel()
	t.tween_property(self, "position", position + Vector2(fly_dir * 16.0, 12.0), TUMBLE_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "rotation_degrees", rotation_degrees + fly_dir * SPIN_DEGREES_PER_SEC * TUMBLE_TIME, TUMBLE_TIME)
	t.tween_property(self, "modulate:a", 0.0, TUMBLE_TIME)
	t.chain().tween_callback(queue_free)


## A hit smacks it back up off the target: a spinning copy pops up and away, fading.
func _hit(enemy: Enemy) -> void:
	var src: Sprite2D = $Sprite2D
	var bounce := Sprite2D.new()
	bounce.texture = src.texture
	bounce.set_meta("ricochet", true)
	bounce.z_index = z_index
	get_parent().add_child(bounce)
	bounce.global_position = src.global_position
	bounce.rotation = rotation
	var back: float = -signf(dir)
	var t := bounce.create_tween().set_parallel()
	t.tween_property(bounce, "global_position:x", bounce.global_position.x + back * 22.0, TUMBLE_TIME)
	t.tween_property(bounce, "global_position:y", bounce.global_position.y - 18.0, TUMBLE_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(bounce, "rotation_degrees", bounce.rotation_degrees + back * 540.0, TUMBLE_TIME)
	t.tween_property(bounce, "modulate:a", 0.0, TUMBLE_TIME).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(bounce.queue_free)
	super._hit(enemy)
