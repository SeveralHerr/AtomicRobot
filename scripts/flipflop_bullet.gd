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


func _init() -> void:
	speed = FLIPFLOP_SPEED


func _spin(delta: float) -> void:
	rotation_degrees += SPIN_DEGREES_PER_SEC * delta


func _hit(enemy: Enemy) -> void:
	# Straight back along the throw: the enemy's lane y can differ from the shot's.
	var from := enemy.global_position - Vector2(dir * 10.0, 0.0)
	super._hit(enemy)
	# The boss is planted (FinalBoss shoves himself 60); a corpse doesn't slide.
	if enemy is FinalBoss or enemy.is_dead:
		return
	EnemyKnockback.apply(enemy, KNOCKBACK, from)
