extends RefCounted
class_name FacingTransform

## Mirror a 2D body to face left or right without going through `scale`.
##
## Two things here are deliberate and both were bugs in the old `scale.x *= -1`
## toggle (`_handle_direction`):
##
## 1. Facing is *absolute*, not a toggle. The old version only flipped when its
##    argument disagreed with the previously *requested* direction, so which way the
##    sprite actually pointed was bookkeeping that any other writer to scale.x/flip_h
##    silently desynced. It also flipped on the *opposite* of the movement direction
##    (callers passed the away-from-target vector), so every new caller had a 50/50
##    chance of coming out mirrored — FindMeterState drew that short straw and
##    walked backwards to every meter.
##
## 2. It writes the transform's basis columns instead of assigning `scale`/`scale.x`.
##    Transform2D has no way to store a negative x-scale, so Godot re-decomposes
##    `scale = (-1, 1)` into `rotation = PI, scale = (1, -1)` — a visually identical
##    mirror, but one that `scale.x` reads back from as *+1*. Worse, Node2D.set_scale
##    only rescales the existing columns and preserves their direction, so once the
##    mirror has migrated into `rotation` no assignment to `scale.x` can undo it and
##    the body is stuck facing the wrong way. Setting the columns is idempotent and
##    survives move_and_slide (which only translates the origin).


## `t` with its basis rebuilt from the authored (unmirrored) `base_scale`, mirrored
## on x when `facing` is -1. The origin is kept.
static func mirrored(t: Transform2D, base_scale: Vector2, facing: int) -> Transform2D:
	t.x = Vector2(base_scale.x * facing, 0.0)
	t.y = Vector2(0.0, base_scale.y)
	return t
