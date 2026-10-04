extends AnimatedSprite2D

## One-shot hit spark (scenes/hit_fx.tscn). Frees itself when the burst ends.

## Opens on the full burst, not the 6px seed frame: a hitstop freezes the first
## frame on screen, and that frame has to read as the impact.
const FIRST_FRAME := 1


func start() -> void:
	animation_finished.connect(queue_free)
	play("default")
	frame = FIRST_FRAME
