class_name ScoreRules
extends RefCounted

## Scoring and rank math for a stage run.
##
## Static and side-effect free so the whole balance table is unit-testable headless
## (test/unit/test_score_rules.gd). The live tracking — combo timer, stage clock,
## persistence — is in scripts/autoload/score_system.gd.
##
## The three things that feed a rank: a combo multiplier (skill), a time bonus
## (aggression) and a no-damage bonus (precision).

# --- Combo -------------------------------------------------------------------

## Seconds a combo survives without a new hit landing. Long enough to cross a lane
## and re-engage, short enough that it is a real resource you can lose.
const COMBO_WINDOW := 2.5

## Combo count at which each multiplier tier starts; the multiplier is the tier's
## index + 1, so this caps at 8x. Front-loaded so the meter feels alive in a normal
## three-enemy scrap, then stretched out so 8x is a genuine achievement.
## Doubled (with POINTS_PER_HIT halved) when maids went from 2 blows to 4 on the
## DamageRules scale: a kill chain pays what it did, tier for tier, kill for kill
## (test_score_rules: test_kill_chain_pays_as_before_the_rescale).
const MULTIPLIER_STEPS: Array[int] = [0, 6, 12, 20, 30, 42, 56, 72]

const POINTS_PER_HIT := 5
const POINTS_PER_KILL := 100


## Score multiplier for a combo count. Always at least 1 — a zero multiplier would
## make ordinary hits worth nothing at all.
static func multiplier_for(combo: int) -> int:
	var m := 1
	for i in MULTIPLIER_STEPS.size():
		if combo >= MULTIPLIER_STEPS[i]:
			m = i + 1
	return m


static func max_multiplier() -> int:
	return MULTIPLIER_STEPS.size()


## Points for landing a hit at `combo` (the count AFTER this hit is counted).
static func hit_points(combo: int) -> int:
	return POINTS_PER_HIT * multiplier_for(combo)


## Points for defeating an enemy at `combo`.
static func kill_points(combo: int) -> int:
	return POINTS_PER_KILL * multiplier_for(combo)


# --- End-of-stage bonuses ----------------------------------------------------

## Target time for the whole run (street + boss), in seconds. Beat it and every second
## saved pays. Tuned (2026-10-03) so the bonus is the same order as the fight score:
## the seed-1 bot clears the completionist route in ~180 s (fight ~7,800, time bonus
## ~3,600); a human taking 5-6 minutes still banks something. When the time bonus was
## per-stage (boss only, 240 s par, 25/s) it paid ~8x the boss fight.
const PAR_SECONDS := 420.0
const POINTS_PER_SECOND_SAVED := 15

## Flat award for finishing a stage without being hit once.
const PERFECT_BONUS := 3000
## ...and the consolation award per health pip still standing if you were hit.
const POINTS_PER_HEALTH_KEPT := 250


## Bonus for clearing in `seconds`. Zero once you are over par — being slow costs you
## the bonus, it never subtracts from the score you earned fighting.
static func time_bonus(seconds: float, par: float = PAR_SECONDS) -> int:
	if seconds >= par:
		return 0
	return roundi((par - seconds) * float(POINTS_PER_SECOND_SAVED))


## Bonus for how little damage you took. `damage_taken` is the number of times the
## player was hit, `health_remaining` the pips left at the finish.
static func no_damage_bonus(damage_taken: int, health_remaining: int) -> int:
	if damage_taken <= 0:
		return PERFECT_BONUS
	return maxi(0, health_remaining) * POINTS_PER_HEALTH_KEPT


## Flat award per secret (cracked wall, newspaper stand) claimed during the run.
const POINTS_PER_SECRET := 250


static func secret_bonus(secrets: int) -> int:
	return maxi(0, secrets) * POINTS_PER_SECRET


# --- Rank --------------------------------------------------------------------

## Rank letters paired with the total score each one needs, best first. rank_for()
## walks this in order and takes the first one the score clears, so D must sit at 0
## to guarantee every run gets a letter.
## Tuned against measured full runs (test_score_rules.gd pins them; re-pinned in
## pf-balance after 4-blow maids, faster swings and +5 street maids): a flawless
## completionist run with its secrets (21.1k) is S, the same without secrets A; the
## mortal completionist bot (188 s, 18 hits, 6 secrets: 16.1k) is A; a fast mortal
## full clear with no secrets (14.3k) is B, as is any decent human clear (~8-12k);
## a slow, battered run with a secret (7.9k) is C, 800 short of B — the player's
## "best full clear ~7k, still C" now sits one secret-and-a-bit below B.
const RANK_THRESHOLDS: Array = [
	["S", 20000],
	["A", 15000],
	["B", 8000],
	["C", 5000],
	["D", 0],
]


static func rank_for(total: int) -> String:
	for entry in RANK_THRESHOLDS:
		if total >= int(entry[1]):
			return String(entry[0])
	return String(RANK_THRESHOLDS[RANK_THRESHOLDS.size() - 1][0])


## Points still needed for the next rank up, or 0 when already at the top rank.
static func points_to_next_rank(total: int) -> int:
	var best := 0
	for entry in RANK_THRESHOLDS:
		var threshold := int(entry[1])
		if total < threshold and (best == 0 or threshold < best):
			best = threshold
	return 0 if best == 0 else best - total


# --- Which scenes are scored -------------------------------------------------

const STREET_SCENE := "res://scenes/main.tscn"
const BOSS_SCENE := "res://scenes/boss_room.tscn"
## The run, in order: the street, then the boss room.
const SCORED_SCENES: Array[String] = [STREET_SCENE, BOSS_SCENE]
## The enemy-behaviour sandboxes opt in as a directory (same convention as
## Lanes.LANE_SCENE_PREFIX) so combo/score can be asserted from a test scene.
const SCORED_SCENE_PREFIX := "res://test/scenes/"


static func is_scored_scene(scene_path: String) -> bool:
	return scene_path in SCORED_SCENES or scene_path.begins_with(SCORED_SCENE_PREFIX)


## True when leaving `from` alive for `to` continues the same run: the street's score,
## clock, damage and secrets carry through the boss door instead of starting over.
static func continues_run(from: String, to: String) -> bool:
	return from == STREET_SCENE and to == BOSS_SCENE


## The full end-of-run breakdown. Pure, so the rank card and the unit tests agree
## on the arithmetic by construction. `fight_score` is the whole run's; `street_score`
## is the part of it banked before the boss door (0 for a boss-only stage).
static func summarise(fight_score: int, seconds: float, damage_taken: int, health_remaining: int,
		par: float = PAR_SECONDS, secrets: int = 0, street_score: int = 0) -> Dictionary:
	var time := time_bonus(seconds, par)
	var perfect := no_damage_bonus(damage_taken, health_remaining)
	var secret := secret_bonus(secrets)
	var bonus := time + perfect + secret
	var total := fight_score + bonus
	var street := clampi(street_score, 0, maxi(fight_score, 0))
	return {
		"fight_score": fight_score,
		"street_score": street,
		"boss_score": fight_score - street,
		"time_bonus": time,
		"no_damage_bonus": perfect,
		"secret_bonus": secret,
		"secrets_found": maxi(0, secrets),
		"bonus": bonus,
		"total": total,
		"rank": rank_for(total),
		"seconds": seconds,
		"damage_taken": damage_taken,
		"health_remaining": health_remaining,
		"perfect": damage_taken <= 0,
	}
