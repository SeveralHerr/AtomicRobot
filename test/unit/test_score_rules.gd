extends RefCounted

# Headless tests for the scoring and rank table (scripts/score_rules.gd).
# ScoreSystem only decides WHEN these fire; every number a player sees comes from
# here, so this is where the balance is pinned.

var _T
const S = preload("res://scripts/score_rules.gd")


# --- Combo multiplier --------------------------------------------------------

func test_no_combo_still_scores() -> String:
	var r: String = _T.assert_eq(S.multiplier_for(0), 1, "no combo is 1x, never 0x")
	if r != "":
		return r
	return _T.assert_gt(S.hit_points(0), 0, "an uncomboed hit is still worth something")


## The multiplier must never go DOWN as the combo goes up — a dip would mean a hit
## that lowers your score, which is indefensible.
func test_multiplier_never_decreases() -> String:
	var previous := 0
	for combo in range(0, 60):
		var m: int = S.multiplier_for(combo)
		if m < previous:
			return "multiplier dropped from %d to %d at combo %d" % [previous, m, combo]
		previous = m
	return ""


func test_multiplier_tiers_match_the_step_table() -> String:
	for i in S.MULTIPLIER_STEPS.size():
		var combo: int = S.MULTIPLIER_STEPS[i]
		var r: String = _T.assert_eq(S.multiplier_for(combo), i + 1,
			"combo %d is tier %d" % [combo, i + 1])
		if r != "":
			return r
	return ""


## The steps must be strictly increasing, or two tiers would share an entry point and
## one multiplier would be unreachable.
func test_multiplier_steps_are_strictly_increasing() -> String:
	for i in range(1, S.MULTIPLIER_STEPS.size()):
		if S.MULTIPLIER_STEPS[i] <= S.MULTIPLIER_STEPS[i - 1]:
			return "step %d (%d) does not exceed step %d (%d)" % [
				i, S.MULTIPLIER_STEPS[i], i - 1, S.MULTIPLIER_STEPS[i - 1]]
	return _T.assert_eq(S.MULTIPLIER_STEPS[0], 0, "the first tier starts at zero combo")


func test_multiplier_caps() -> String:
	var r: String = _T.assert_eq(S.multiplier_for(9999), S.max_multiplier(), "caps at the top tier")
	if r != "":
		return r
	return _T.assert_eq(S.max_multiplier(), 8, "eight tiers ship")


func test_kills_are_worth_more_than_hits() -> String:
	return _T.assert_gt(S.kill_points(0), S.hit_points(0), "a kill beats a chip hit")


func test_points_scale_with_the_multiplier() -> String:
	var low: int = S.kill_points(0)
	var high: int = S.kill_points(S.MULTIPLIER_STEPS[S.MULTIPLIER_STEPS.size() - 1])
	return _T.assert_eq(high, low * S.max_multiplier(), "top tier pays the full multiple")


# --- Time bonus --------------------------------------------------------------

func test_time_bonus_is_zero_at_and_over_par() -> String:
	var r: String = _T.assert_eq(S.time_bonus(S.PAR_SECONDS), 0, "exactly par pays nothing")
	if r != "":
		return r
	return _T.assert_eq(S.time_bonus(S.PAR_SECONDS + 500.0), 0, "over par never goes negative")


func test_time_bonus_rewards_going_faster() -> String:
	var quick: int = S.time_bonus(60.0)
	var slow: int = S.time_bonus(200.0)
	var r: String = _T.assert_gt(quick, slow, "faster clears pay more")
	if r != "":
		return r
	return _T.assert_eq(S.time_bonus(S.PAR_SECONDS - 10.0), 10 * S.POINTS_PER_SECOND_SAVED,
		"each second saved pays the stated rate")


# --- No-damage bonus ---------------------------------------------------------

## A flawless run must beat any damaged run outright, whatever health was left —
## otherwise "don't get hit" is not actually the goal it is sold as.
func test_perfect_run_beats_every_damaged_run() -> String:
	var perfect: int = S.no_damage_bonus(0, 1)
	for health in range(0, 11):
		var damaged: int = S.no_damage_bonus(1, health)
		if damaged >= perfect:
			return "damaged run with %d health scored %d, matching the perfect bonus %d" % [
				health, damaged, perfect]
	return ""


func test_damaged_run_still_pays_for_health_kept() -> String:
	var r: String = _T.assert_eq(S.no_damage_bonus(3, 2), 2 * S.POINTS_PER_HEALTH_KEPT,
		"two pips left pays for two")
	if r != "":
		return r
	return _T.assert_eq(S.no_damage_bonus(3, 0), 0, "no health left pays nothing")


## Health can read negative for a moment after a fatal overkill hit; the bonus must
## floor at zero rather than subtracting from the score.
func test_negative_health_cannot_subtract() -> String:
	return _T.assert_eq(S.no_damage_bonus(5, -3), 0, "negative health floors at zero")


# --- Rank --------------------------------------------------------------------

## Every possible score must produce a letter. A run that finishes with no rank is a
## blank card on the end-of-stage screen.
func test_every_score_gets_a_rank() -> String:
	for total in [-100, 0, 1, 4999, 5000, 13999, 19999, 20000, 999999]:
		var rank: String = S.rank_for(total)
		var r: String = _T.assert_true(rank != "", "score %d has a rank" % total)
		if r != "":
			return r
	return ""


func test_rank_thresholds_are_ordered_best_first_and_bottom_out_at_zero() -> String:
	var previous := 99999999
	for entry in S.RANK_THRESHOLDS:
		var threshold := int(entry[1])
		if threshold >= previous:
			return "rank %s (%d) is not below the entry above it (%d)" % [entry[0], threshold, previous]
		previous = threshold
	# The last entry has to be reachable by a score of 0, or a bad run gets no letter.
	return _T.assert_eq(int(S.RANK_THRESHOLDS[S.RANK_THRESHOLDS.size() - 1][1]), 0,
		"the bottom rank starts at zero")


func test_rank_improves_with_score() -> String:
	var r: String = _T.assert_eq(S.rank_for(0), "D", "a bad run ranks D")
	if r != "":
		return r
	var top := _threshold("S")
	r = _T.assert_eq(S.rank_for(top), "S", "clearing the top threshold ranks S")
	if r != "":
		return r
	return _T.assert_eq(S.rank_for(top - 1), "A", "one point short of S is A")


func _threshold(rank: String) -> int:
	for entry in S.RANK_THRESHOLDS:
		if entry[0] == rank:
			return int(entry[1])
	return -1


func test_points_to_next_rank() -> String:
	var r: String = _T.assert_eq(S.points_to_next_rank(_threshold("C") - 1), 1, "one point from C")
	if r != "":
		return r
	return _T.assert_eq(S.points_to_next_rank(_threshold("S")), 0, "nothing left to climb at S")


# --- Summary -----------------------------------------------------------------

## The rank card and these tests must agree on the arithmetic by construction: the
## total is exactly the three parts, with nothing added or dropped in between.
func test_summary_total_is_the_sum_of_its_parts() -> String:
	var result: Dictionary = S.summarise(7000, 100.0, 2, 3)
	var expected: int = int(result["fight_score"]) + int(result["time_bonus"]) + int(result["no_damage_bonus"])
	var r: String = _T.assert_eq(int(result["total"]), expected, "total is the sum of the parts")
	if r != "":
		return r
	return _T.assert_eq(String(result["rank"]), S.rank_for(int(result["total"])), "rank matches the total")


func test_summary_flags_a_flawless_run() -> String:
	var flawless: Dictionary = S.summarise(1000, 60.0, 0, 3)
	var r: String = _T.assert_true(bool(flawless["perfect"]), "no hits taken is perfect")
	if r != "":
		return r
	var hit: Dictionary = S.summarise(1000, 60.0, 1, 3)
	return _T.assert_false(bool(hit["perfect"]), "one hit taken is not perfect")


## Two runs with identical fights but different times must not tie — the time bonus
## has to actually reach the total.
func test_faster_run_outscores_slower_identical_run() -> String:
	var fast: Dictionary = S.summarise(5000, 30.0, 0, 3)
	var slow: Dictionary = S.summarise(5000, 200.0, 0, 3)
	return _T.assert_gt(int(fast["total"]), int(slow["total"]), "the faster clear wins")


# --- Scene gating ------------------------------------------------------------

func test_scored_scene_gating() -> String:
	var r: String = _T.assert_true(S.is_scored_scene("res://scenes/main.tscn"), "the street level scores")
	if r != "":
		return r
	r = _T.assert_true(S.is_scored_scene("res://scenes/boss_room.tscn"), "the boss room scores")
	if r != "":
		return r
	r = _T.assert_true(S.is_scored_scene("res://test/scenes/melee_cluster.tscn"),
		"sandboxes opt in by directory so combo can be asserted in tests")
	if r != "":
		return r
	r = _T.assert_false(S.is_scored_scene("res://scenes/startscreen.tscn"), "menus do not score")
	if r != "":
		return r
	return _T.assert_false(S.is_scored_scene(""), "no scene does not score")


# --- The run: street + boss + bonus ------------------------------------------

func test_run_subtotals_add_up() -> String:
	var res: Dictionary = S.summarise(8000, 150.0, 2, 5, S.PAR_SECONDS, 3, 6500)
	var r: String = _T.assert_eq(int(res["street_score"]) + int(res["boss_score"]), int(res["fight_score"]),
		"street + boss is the fight score")
	if r != "":
		return r
	r = _T.assert_eq(int(res["boss_score"]), 1500, "boss is what came after the door")
	if r != "":
		return r
	r = _T.assert_eq(int(res["bonus"]), int(res["time_bonus"]) + int(res["no_damage_bonus"]) + int(res["secret_bonus"]),
		"bonus is time + health + secrets")
	if r != "":
		return r
	return _T.assert_eq(int(res["total"]), int(res["fight_score"]) + int(res["bonus"]), "total is fight + bonus")


## A boss-only stage (debug start) has no street part; a bogus street score can never
## make the boss part negative.
func test_run_street_score_is_clamped() -> String:
	var r: String = _T.assert_eq(int(S.summarise(900, 50.0, 1, 2)["street_score"]), 0, "no street by default")
	if r != "":
		return r
	var res: Dictionary = S.summarise(900, 50.0, 1, 2, S.PAR_SECONDS, 0, 5000)
	return _T.assert_eq(int(res["boss_score"]), 0, "street can't exceed the fight score")


func test_run_secrets_pay_per_secret() -> String:
	var r: String = _T.assert_eq(S.secret_bonus(0), 0, "none found, nothing paid")
	if r != "":
		return r
	r = _T.assert_eq(S.secret_bonus(3), 3 * S.POINTS_PER_SECRET, "flat per secret")
	if r != "":
		return r
	r = _T.assert_eq(S.secret_bonus(-2), 0, "never negative")
	if r != "":
		return r
	var with: Dictionary = S.summarise(1000, 300.0, 1, 1, S.PAR_SECONDS, 2)
	var without: Dictionary = S.summarise(1000, 300.0, 1, 1, S.PAR_SECONDS, 0)
	return _T.assert_eq(int(with["total"]) - int(without["total"]), 2 * S.POINTS_PER_SECRET, "secrets reach the total")


func test_run_continues_only_through_the_boss_door() -> String:
	var r: String = _T.assert_true(S.continues_run(S.STREET_SCENE, S.BOSS_SCENE), "street -> boss carries")
	if r != "":
		return r
	for pair in [[S.BOSS_SCENE, S.BOSS_SCENE], [S.STREET_SCENE, S.STREET_SCENE], ["", S.BOSS_SCENE],
			[S.BOSS_SCENE, S.STREET_SCENE], ["res://test/scenes/melee_cluster.tscn", S.BOSS_SCENE]]:
		if S.continues_run(pair[0], pair[1]):
			return "%s -> %s must start a fresh run" % pair
	return ""



# --- Balance pins: reference runs (autoplay seed 1, Ryan, 2026-10-03) -----------
# Measured with `python tools/autoplay.py` (the "run:" line). Retune the constants,
# not these runs, unless the level itself changed.

## Completionist route, mortal: street 7,070 + boss 770, 182.5 s, 20 hits, 4 orbs
## left, and 6 of the 7 secrets the route visits.
func _clean_run() -> Dictionary:
	return S.summarise(7840, 182.5, 20, 4, S.PAR_SECONDS, 6, 7070)


func test_balance_bonus_is_the_same_order_as_the_fight() -> String:
	var res := _clean_run()
	var ratio := float(res["bonus"]) / float(res["fight_score"])
	if ratio < 0.5 or ratio > 1.5:
		return "bonus %d vs fight %d (ratio %.2f): should be the same order" % [res["bonus"], res["fight_score"], ratio]
	var time_ratio := float(res["time_bonus"]) / float(res["fight_score"])
	if time_ratio > 1.0:
		return "time bonus alone (%d) outweighs the fight (%d)" % [res["time_bonus"], res["fight_score"]]
	return ""


func test_balance_clean_full_run_ranks_a() -> String:
	return _T.assert_eq(String(_clean_run()["rank"]), "A", "clean mortal completionist run")


## The god-mode bot's completionist run (no hits, 175.7 s, fight 10,180) with every
## secret: as good as a run gets.
func test_balance_flawless_run_ranks_s() -> String:
	var res: Dictionary = S.summarise(10180, 175.7, 0, 10, S.PAR_SECONDS, 7, 7390)
	return _T.assert_eq(String(res["rank"]), "S", "flawless, fast, every secret")


## A sloppy run: slow (5.5 min), battered to one orb, one secret, a thinner fight.
func test_balance_sloppy_run_ranks_c() -> String:
	var res: Dictionary = S.summarise(6000, 330.0, 30, 1, S.PAR_SECONDS, 1, 5400)
	return _T.assert_eq(String(res["rank"]), "C", "slow, battered, few secrets")


## Mutation survivor: S must need the secrets too. The same flawless run with none
## of them stays A.
func test_balance_flawless_run_without_secrets_is_a() -> String:
	var res: Dictionary = S.summarise(10180, 175.7, 0, 10, S.PAR_SECONDS, 0, 7390)
	return _T.assert_eq(String(res["rank"]), "A", "S needs the secrets as well")


## Maids went from 2 blows to 4 (DamageRules). A chain of kills must pay what it did:
## the pre-rescale table (steps [0,3,6,10,15,21,28,36], 10/hit) at 2 hits a kill vs the
## live one at 4. Within 5% — the hits inside a kill land on slightly different tiers.
func test_kill_chain_pays_as_before_the_rescale() -> String:
	var old_steps := [0, 3, 6, 10, 15, 21, 28, 36]
	var old_mult := func(c: int) -> int:
		var m := 1
		for i in old_steps.size():
			if c >= old_steps[i]:
				m = i + 1
		return m
	for kills in [3, 10, 25]:
		var old_total := 0
		var combo := 0
		for k in kills:
			for h in 2:
				combo += 1
				old_total += 10 * old_mult.call(combo)
			old_total += 100 * old_mult.call(combo)
		var new_total := 0
		combo = 0
		for k in kills:
			for h in 4:
				combo += 1
				new_total += S.hit_points(combo)
			new_total += S.kill_points(combo)
		if absf(new_total - old_total) > 0.05 * old_total:
			return "%d kills: %d now vs %d before" % [kills, new_total, old_total]
	return ""
