extends RefCounted
class_name BossRules

## Every number that decides how the City Council fight plays, in one table, so a
## balance pass is a data edit. Pure and static — unit tested in test_boss_rules.gd.
##
## The fight has three phases keyed off the boss's remaining health. Each later phase
## stacks a new attack on top of the last one, so the player learns them one at a time:
##   0 IN SESSION   aimed briefcases only
##   1 BUDGET CUTS  fan bursts + telegraphed ceiling drops + meter-maid reinforcements
##
## A fan's extra briefcases are stepped upward, over a standing player's head, so
## only the first can hit someone on the ground — the fan punishes jumping.
##   2 OVERTIME     faster, wider fans, more drops, and a charge across the room

## On the DamageRules scale. Fighters hit for 3-4: 20 blows for Ryan, 15 for Cody
## (was 20 HP vs 1-2 damage: 20 and 10). test_damage_scale pins 10-20 for everyone.
const MAX_HEALTH := 60

## Health fraction at or below which phase N (index) begins. Phase 0 is the opener.
const PHASE_STARTS: Array[float] = [1.0, 0.66, 0.33]

## Seconds the boss is invulnerable (and silent) while he rages into a new phase —
## the beat that lets the phase banner read and the player reset.
const STAGGER_TIME := 1.4

## Seconds after FIGHT! before his first throw: the FIGHT! flash would otherwise
## cover the first wind-up, and the player has only just got control back.
const OPENING_GRACE := 1.0

## Ceiling drops: how long the floor marker warns before the briefcase falls, and the
## minimum spacing between drops in one volley so there is always a gap to stand in.
const DROP_WARN := 0.9
const DROP_MIN_GAP := 110.0

## throw_delay is the fight's main difficulty knob: seconds he idles between throws.
## Raised from 1.7/1.35/1.2 (now 2.0/1.7/1.5, plus OPENING_GRACE) once health carried in from the street — the bot took ~16
## hits a fight and arrived with ~5. Pinned by test_throw_cadence_leaves_room_to_hit_back
## and the seeded boss_balance_* / *_mortal autoplay scenarios.
const PHASES: Array[Dictionary] = [
	{
		"title": "FINAL BOSS", "sub": "THE CITY COUNCILMAN",
		"line": "We are charging for\nparking on SUNDAYS!",
		"throw_delay": 2.0, "burst": 1, "spread_deg": 0.0,
		"drop_every": 0.0, "drop_count": 0, "maids": 0, "dash_every": 0,
	},
	{
		"title": "BUDGET CUTS!", "sub": "PHASE 2",
		"line": "Meter maids,\nto the chamber!",
		"throw_delay": 1.7, "burst": 3, "spread_deg": 14.0,
		"drop_every": 4.5, "drop_count": 3, "maids": 2, "dash_every": 0,
	},
	{
		"title": "OVERTIME!", "sub": "FINAL PHASE",
		"line": "This meeting is\nNOT adjourned!",
		"throw_delay": 1.5, "burst": 3, "spread_deg": 18.0,
		"drop_every": 4.0, "drop_count": 3, "maids": 0, "dash_every": 3,
	},
]


## Phase for `health` out of `max_health`. A dead boss stays in the last phase.
static func phase_for(health: int, max_health: int = MAX_HEALTH) -> int:
	var frac := float(health) / float(maxi(max_health, 1))
	var phase := 0
	for i in PHASE_STARTS.size():
		if frac <= PHASE_STARTS[i]:
			phase = i
	return phase


static func params(phase: int) -> Dictionary:
	return PHASES[clampi(phase, 0, PHASES.size() - 1)]


## X positions for one ceiling-drop volley inside [left, right]: `count` drops at
## least DROP_MIN_GAP apart (fewer if the span can't fit them), so the player always
## has somewhere to stand. `rng` makes it deterministic under the autoplay seed.
static func drop_xs(count: int, left: float, right: float, rng: RandomNumberGenerator) -> Array[float]:
	var xs: Array[float] = []
	var n := mini(count, maxi(int((right - left) / DROP_MIN_GAP), 1))
	if n <= 0 or right <= left:
		return xs
	# n equal slots (each >= DROP_MIN_GAP wide), one drop per slot kept half a gap
	# from the slot's edges — so neighbours are DROP_MIN_GAP apart by construction.
	var slot := (right - left) / float(n)
	var lo := minf(slot, DROP_MIN_GAP) * 0.5
	for i in n:
		xs.append(left + slot * i + lo + rng.randf_range(0.0, slot - 2.0 * lo))
	return xs
