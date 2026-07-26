class_name PowerupRules
extends RefCounted

## Definitions and pure math for the timed power-up system.
##
## Everything here is static and side-effect free so it can be unit-tested headless
## (test/unit/test_powerup_rules.gd). The live wiring — timers, stat application,
## shader uniforms — is in scripts/autoload/powerup_system.gd.
##
## Design constraint that shapes all of this: there is NO new character art. A
## power-up may only change numbers the existing states already read (damage, speed,
## animation speed_scale) and recolour the existing sprite through the shader on
## DefaultSprite. Nothing may require a new animation.

const RAGE := "rage"
const OVERCLOCK := "overclock"

## Draw/roll order. Also the order the HUD lists active buffs in.
const IDS: Array[String] = [RAGE, OVERCLOCK]

## `weight` is the relative chance of this id being the one that drops, given that
## a drop happens at all — see pick(). `duration` is seconds.
##
## The shader fields map 1:1 onto the buff_* uniforms in shaders/flash.gdshader:
## `pixel_size` is the screen-space size of one dither cell (so the effect reads as
## chunky pixels rather than a smooth glow) and `dither` is how much of that cell
## grid actually shows through.
const DEFS := {
	RAGE: {
		"label": "ATOMIC RAGE",
		"duration": 8.0,
		"damage_multiplier": 2.0,
		"speed_multiplier": 1.0,
		"attack_speed_multiplier": 1.0,
		"color": Color(1.0, 0.28, 0.10),
		"pulse_hz": 3.0,
		"pixel_size": 6.0,
		"dither": 0.55,
		"weight": 1.0,
	},
	OVERCLOCK: {
		"label": "OVERCLOCK",
		"duration": 8.0,
		"damage_multiplier": 1.0,
		"speed_multiplier": 1.6,
		"attack_speed_multiplier": 1.75,
		"color": Color(0.18, 0.92, 1.0),
		"pulse_hz": 7.0,
		"pixel_size": 4.0,
		"dither": 0.8,
		"weight": 1.0,
	},
}

## Chance that a defeated enemy drops anything at all. Kept low on purpose: a drop
## should punctuate a fight, not be its normal rhythm.
const BASE_DROP_CHANCE := 0.10
## ...but never let a player go this many kills with nothing. A pure 10% roll runs
## 16 kills dry about 19% of the time, which in a fight-heavy level reads as
## "power-ups are broken" rather than "unlucky". The pity counter makes the floor
## deterministic without making the common case predictable.
##
## Together these average a drop every ~8 kills ((1 - 0.9^16) / 0.10). The previous
## 0.22 / 8 pairing averaged one every ~3.9, which had power-ups dropping faster than
## an 8-second buff expires — the buffed state was the default state.
const PITY_KILLS := 16

## Seconds a dropped pickup sits in the world before it despawns, and how long before
## that it starts blinking to warn you.
const PICKUP_LIFETIME := 12.0
const PICKUP_BLINK_LEAD := 3.0

## Fraction of `duration` spent fading the shader overlay in and back out, so a buff
## starting or ending never pops. Applied at both ends, hence the 0.5 ceiling.
const RAMP_FRACTION := 0.12


static func has_id(id: String) -> bool:
	return DEFS.has(id)


## Definition dictionary for `id`, or an empty one for an unknown id — callers read
## fields off this with .get() defaults, so an unknown id degrades to "no effect"
## rather than crashing a live game.
static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func duration(id: String) -> float:
	return float(def(id).get("duration", 0.0))


static func label(id: String) -> String:
	return String(def(id).get("label", id.to_upper()))


static func color(id: String) -> Color:
	return def(id).get("color", Color.WHITE)


## Which power-up a drop rolls into, from a 0..1 uniform `roll`, weighted by DEFS.
##
## Takes the roll rather than calling randf() so drop tables are testable and so a
## devtools verb can force a specific outcome.
static func pick(roll: float) -> String:
	var total := 0.0
	for id in IDS:
		total += float(def(id).get("weight", 0.0))
	if total <= 0.0:
		return ""
	var target := clampf(roll, 0.0, 0.999999) * total
	var running := 0.0
	for id in IDS:
		running += float(def(id).get("weight", 0.0))
		if target < running:
			return id
	return IDS[IDS.size() - 1]


## Does this kill drop a power-up? `kills_since_drop` counts kills since the last
## drop (0 on the kill right after one). `roll` is a 0..1 uniform.
static func should_drop(kills_since_drop: int, roll: float) -> bool:
	if kills_since_drop >= PITY_KILLS:
		return true
	return roll < BASE_DROP_CHANCE


## Combined stat multipliers for a set of simultaneously active ids.
##
## Multiplicative, so stacking Rage and Overclock genuinely compounds — they buff
## different stats in practice, but the combine has to be defined for the case where
## two drops of the same kind of buff overlap.
static func stack(active_ids: Array) -> Dictionary:
	var out := {"damage_multiplier": 1.0, "speed_multiplier": 1.0, "attack_speed_multiplier": 1.0}
	for id in active_ids:
		var d := def(String(id))
		for key in out:
			out[key] = float(out[key]) * float(d.get(key, 1.0))
	return out


## Shader parameters for a set of active buffs, blended by each one's current
## `strength` (0..1 ramp). Returns the buff_* uniform values for flash.gdshader.
##
## `active` is an Array of { "id": String, "strength": float }. Colours are blended
## weighted by strength so a Rage fading out while an Overclock fades in crossfades
## rather than snapping between palettes.
static func shader_params(active: Array) -> Dictionary:
	var out := {
		"buff_color": Color.WHITE,
		"buff_value": 0.0,
		"buff_pulse_hz": 0.0,
		"buff_pixel_size": 0.0,
		"buff_dither": 0.0,
	}
	var total_weight := 0.0
	var color_sum := Vector3.ZERO
	var pulse := 0.0
	var pixel := 0.0
	var dither := 0.0
	var strongest := 0.0
	for entry in active:
		var id := String(entry.get("id", ""))
		var strength := clampf(float(entry.get("strength", 0.0)), 0.0, 1.0)
		if strength <= 0.0 or not has_id(id):
			continue
		var d := def(id)
		var c: Color = d.get("color", Color.WHITE)
		color_sum += Vector3(c.r, c.g, c.b) * strength
		pulse += float(d.get("pulse_hz", 0.0)) * strength
		pixel += float(d.get("pixel_size", 0.0)) * strength
		dither += float(d.get("dither", 0.0)) * strength
		total_weight += strength
		strongest = maxf(strongest, strength)
	if total_weight <= 0.0:
		return out
	var avg := color_sum / total_weight
	out["buff_color"] = Color(avg.x, avg.y, avg.z)
	# The master strength is the strongest single buff, not the sum: two buffs should
	# not wash the sprite out to a flat colour, they should blend hue and keep the
	# same overall intensity.
	out["buff_value"] = strongest
	out["buff_pulse_hz"] = pulse / total_weight
	out["buff_pixel_size"] = pixel / total_weight
	out["buff_dither"] = dither / total_weight
	return out


## Ramp strength (0..1) for a buff with `remaining` seconds left of `total`.
##
## Fades in over the first RAMP_FRACTION of the duration and back out over the last,
## so the recolour never pops on or off. Degrades to a hard 1.0 for zero-length
## definitions rather than dividing by zero.
static func ramp_strength(remaining: float, total: float) -> float:
	if total <= 0.0:
		return 0.0
	var ramp := minf(total * RAMP_FRACTION, total * 0.5)
	if ramp <= 0.0:
		return 1.0 if remaining > 0.0 else 0.0
	var elapsed := total - remaining
	if elapsed < 0.0 or remaining <= 0.0:
		return 0.0
	return clampf(minf(elapsed / ramp, remaining / ramp), 0.0, 1.0)
