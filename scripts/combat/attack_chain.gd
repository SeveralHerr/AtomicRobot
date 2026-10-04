extends RefCounted
class_name AttackChain

## Timing rules for one string of player swings, kept apart from AttackState so the
## numbers sit side by side and test without a scene. Frame numbers are the Attack
## animation's own frames, so a power-up that speeds the sprite speeds all of this.
##
## A swing commits until its hit frame. RECOVERY_FRAMES later its follow-through
## becomes cancellable: move, jump or lane-step out of it, or chain the next swing off
## a press made any time during it (buffered). The last step of the string (the
## finisher) never chains early: it plays out, then a buffered press starts a new string.

## Attack animation playback rate (x the authored 15 fps). Multiplies with
## AnimatedSprite2D.speed_scale, which belongs to PowerupSystem (Overclock).
const ANIM_SPEED := 1.4
## Animation frames after the hit frame before the swing can be cancelled or chained.
const RECOVERY_FRAMES := 2
## Swings in a string; the last one is the finisher.
const MAX_STEPS := 3
## Ground drift while swinging, as a fraction of walk speed (input-steered, no turning).
const DRIFT := 0.3
## Forward step (px/s, bleeds off by Player.FRICTION: ~9px) on each chained swing, so
## a string reads as pressing forward rather than one swing on repeat.
const LUNGE := 120.0

## 0-based position in the current string.
var step := 0
## The current swing's hit frame has fired.
var hit_done := false
## Attack was pressed during the current swing.
var buffered := false


## A fresh string (entering the attack state, or after a finisher).
func reset() -> void:
	step = 0
	_swing()


## The next swing of the string.
func advance() -> void:
	step += 1
	_swing()


func _swing() -> void:
	hit_done = false
	buffered = false


func is_finisher() -> bool:
	return step >= MAX_STEPS - 1


## The follow-through can be cancelled by movement / jump / lane step.
func in_recovery(frame: int, hit_frame: int) -> bool:
	return hit_done and frame >= hit_frame + RECOVERY_FRAMES


## A buffered press should start the next swing now.
func should_chain(frame: int, hit_frame: int) -> bool:
	return buffered and not is_finisher() and in_recovery(frame, hit_frame)
