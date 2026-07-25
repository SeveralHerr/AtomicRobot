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
	r = _T.assert_eq(S.rank_for(20000), "S", "clearing the top threshold ranks S")
	if r != "":
		return r
	return _T.assert_eq(S.rank_for(19999), "A", "one point short of S is A")


func test_points_to_next_rank() -> String:
	var r: String = _T.assert_eq(S.points_to_next_rank(4999), 1, "one point from C")
	if r != "":
		return r
	return _T.assert_eq(S.points_to_next_rank(20000), 0, "nothing left to climb at S")


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
