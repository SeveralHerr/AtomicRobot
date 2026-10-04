extends RefCounted
class_name HitWords

## Which comic word a landed player blow gets, so a fast 3-swing string reads as one
## rising beat instead of a stack of words: the first hit pops a word, a follow-up
## re-punches that SAME word (bigger, tilt flipped), the string's finisher replaces it
## with a heavier word, and the kill slams a KO! over everything.
##
## Rank decides: a bigger moment replaces the live word, an equal one re-punches it,
## a smaller one (a jab right after a finisher or KO) leaves the big word alone.

const RANK := {&"hit": 1, &"boss_hit": 1, &"finisher": 2, &"ko": 3}
## Card centre above the target's origin (world px) for a size-1 word, before
## ComicPopup clamps it. Bigger words rise by their extra half-height, so every
## word's bottom edge sits at the same height above the fighters' heads.
const LIFT := Vector2(0.0, -40.0)
## Nudge (world px) away from the attacker: centred on the target, the card's near
## half sat over the player's head on every blow.
const AWAY := 10.0


## Where the centre of a `kind` word goes over a target at `origin`.
static func anchor(origin: Vector2, kind: StringName) -> Vector2:
	var size := float(ComicPopup.KINDS.get(kind, {}).get("size", 1.0))
	var extra := ComicPopup.CARD_H * 0.5 * ComicPopup.BASE_SCALE * maxf(0.0, size - 1.0)
	return origin + LIFT - Vector2(0.0, extra)


## The word kind for a blow. &"" = no word (the boss's death has its own show).
static func kind_for(killed: bool, finisher: bool, boss: bool) -> StringName:
	if killed:
		return &"" if boss else &"ko"
	if finisher:
		return &"finisher"
	return &"boss_hit" if boss else &"hit"


## &"spawn" a new word, &"bump" (re-punch) the live one, or &"none".
## `live_kind` is the kind of the word on screen (&"" when there is none).
static func action(kind: StringName, live_kind: StringName) -> StringName:
	if not RANK.has(kind):
		return &"none"
	var rank: int = RANK[kind]
	var live_rank: int = RANK.get(live_kind, 0)
	if rank > live_rank:
		return &"spawn"
	if rank == live_rank:
		return &"bump"
	return &"none"


## Shows the word for a blow on `target` from an attacker standing at `from_x`.
## Returns the popup shown or bumped, or null.
static func land(target: Node2D, killed: bool, finisher: bool, from_x: float = NAN) -> ComicPopup:
	var kind := kind_for(killed, finisher, target is FinalBoss)
	var live := ComicPopup.live()
	var at := anchor(target.global_position, kind)
	if not is_nan(from_x):
		at.x += AWAY * signf(target.global_position.x - from_x)
	match action(kind, live.kind if live != null else &""):
		&"spawn":
			var popup := ComicPopup.spawn(target, at, kind)
			if popup != null and live != null:
				# Gone at once, not on the usual retire shrink: the hitstop that comes
				# with this blow freezes that shrink, leaving the old word peeking out
				# under the new one.
				live.visible = false
			return popup
		&"bump":
			live.restrike(at)
			return live
	return null
