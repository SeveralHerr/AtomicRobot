extends RefCounted
class_name SfxPitch

## Subtle pitch variation so repeated player sounds don't machine-gun. Each combo step
## lifts the pitch a notch; a small random jitter rides on top. JITTER < STEP_RISE / 2,
## so a later step is always higher than an earlier one whatever the rolls.

const STEP_RISE := 0.06
const JITTER := 0.025


## Pitch for combo `step` (0-based) and a uniform `roll` in [0, 1).
static func for_step(step: int, roll: float) -> float:
	return 1.0 + STEP_RISE * step + (roll * 2.0 - 1.0) * JITTER


## Sets `player`'s pitch for `step` (random jitter) and plays it.
static func play(player: Node, step: int = 0) -> void:
	player.pitch_scale = for_step(step, randf())
	player.play()
