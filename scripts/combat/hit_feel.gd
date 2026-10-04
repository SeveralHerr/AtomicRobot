extends RefCounted
class_name HitFeel

## Impact feedback for a blow the player lands: sparks at the contact point, a camera
## kick and a hitstop, a notch heavier on the kill. Every player hit (melee and both
## projectile characters) funnels through Player.land_hit -> here, so all characters
## feel the same and the numbers are tuned side by side.

## Hitstop, real seconds. The kill freeze is longer so the finishing blow reads.
const HIT_STOP := 0.05
const KILL_STOP := 0.12
## Camera kick (px, s). Small: a combo is several of these in a row.
const HIT_SHAKE := 3.0
const HIT_SHAKE_TIME := 0.15
const KILL_SHAKE := 6.0
const KILL_SHAKE_TIME := 0.25
## Sparks sit on the target's attacker-facing side, about chest height.
const CONTACT_INSET := 14.0
const CONTACT_RISE := 12.0


## Where on `target` (world) a blow from `attacker` (world) connects.
static func contact_point(attacker: Vector2, target: Vector2) -> Vector2:
	var side := signf(attacker.x - target.x)
	return Vector2(target.x + side * CONTACT_INSET, target.y - CONTACT_RISE)


static func hit_landed(attacker: Node2D, target: Node2D, killed: bool) -> void:
	Utils.hit_effect(target, contact_point(attacker.global_position, target.global_position))
	if killed:
		ScreenShake.apply_shake(KILL_SHAKE, KILL_SHAKE_TIME)
		Utils.apply_hit_pause(target, KILL_STOP)
	else:
		ScreenShake.apply_shake(HIT_SHAKE, HIT_SHAKE_TIME)
		Utils.apply_hit_pause(target, HIT_STOP)
