extends LaneProjectile

const SPIN_DEGREES_PER_SEC: float = 600.0


func _spin(delta: float) -> void:
	rotation_degrees += SPIN_DEGREES_PER_SEC * delta
