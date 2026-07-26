extends RefCounted

# Headless tests for the power-up definition table and drop math
# (scripts/powerup_rules.gd). Everything the live PowerupSystem does is a thin
# wrapper over these, so this is where the balance is actually pinned.

var _T
const P = preload("res://scripts/powerup_rules.gd")


## Every id in IDS must have a complete, sane definition — a missing duration or a
## zero weight would produce a buff that can drop but instantly expires, or one that
## exists in the HUD but can never be rolled.
func test_every_definition_is_complete() -> String:
	for id in P.IDS:
		var d: Dictionary = P.def(id)
		var r: String = _T.assert_true(not d.is_empty(), "%s has a definition" % id)
		if r != "":
			return r
		for key in ["label", "duration", "damage_multiplier", "speed_multiplier",
				"attack_speed_multiplier", "color", "weight"]:
			r = _T.assert_true(d.has(key), "%s defines %s" % [id, key])
			if r != "":
				return r
		r = _T.assert_gt(float(d["duration"]), 0.0, "%s lasts a non-zero time" % id)
		if r != "":
			return r
		r = _T.assert_gt(float(d["weight"]), 0.0, "%s can actually be rolled" % id)
		if r != "":
			return r
	return ""


## Pins the shipped roster. The rest of the suite iterates IDS and would pass with
## any contents, so this is the tripwire that makes adding a power-up deliberate.
func test_shipped_roster() -> String:
	var r: String = _T.assert_eq(P.IDS.size(), 2, "two power-ups ship")
	if r != "":
		return r
	r = _T.assert_true(P.has_id(P.RAGE), "rage exists")
	if r != "":
		return r
	return _T.assert_true(P.has_id(P.OVERCLOCK), "overclock exists")


## An unknown id must degrade to "no effect" rather than crash — ids arrive from
## saved pickups and devtools args, and a live game should not die on a typo.
func test_unknown_id_is_inert() -> String:
	var r: String = _T.assert_false(P.has_id("banana"), "unknown id is not known")
	if r != "":
		return r
	r = _T.assert_true(P.def("banana").is_empty(), "unknown id has no definition")
	if r != "":
		return r
	r = _T.assert_float_eq(P.duration("banana"), 0.0, 0.0001, "unknown id has no duration")
	if r != "":
		return r
	var stats: Dictionary = P.stack(["banana"])
	return _T.assert_float_eq(float(stats["damage_multiplier"]), 1.0, 0.0001,
		"unknown id changes no stats")


## pick() must return a real id for every point in the 0..1 roll space — a gap would
## be a drop that spawns nothing and silently eats the pity counter reset.
func test_pick_covers_the_whole_roll_range() -> String:
	for i in 101:
		var roll := float(i) / 100.0
		var id: String = P.pick(roll)
		var r: String = _T.assert_true(P.has_id(id), "roll %f picked a real id (got '%s')" % [roll, id])
		if r != "":
			return r
	return ""


## Out-of-range rolls are clamped, not wrapped — 1.0 is a legal randf() result and
## must not fall off the end of the weight table.
func test_pick_clamps_out_of_range_rolls() -> String:
	var r: String = _T.assert_true(P.has_id(P.pick(1.0)), "roll of exactly 1.0 still picks")
	if r != "":
		return r
	r = _T.assert_eq(P.pick(0.0), P.IDS[0], "roll of 0 picks the first entry")
	if r != "":
		return r
	return _T.assert_true(P.has_id(P.pick(-0.5)), "negative roll still picks")


## With equal weights the split must land on the halfway mark. This is what makes
## "both power-ups drop about equally often" a fact rather than a hope.
func test_pick_splits_equal_weights_evenly() -> String:
	var first := 0
	for i in 1000:
		if P.pick(float(i) / 1000.0) == P.IDS[0]:
			first += 1
	# Both shipped entries have weight 1.0, so exactly half the roll space is the first.
	return _T.assert_true(absi(first - 500) <= 1,
		"even weights split the roll space evenly (got %d/1000)" % first)


func test_drop_roll_respects_the_base_chance() -> String:
	var r: String = _T.assert_true(P.should_drop(0, 0.0), "a roll of 0 always drops")
	if r != "":
		return r
	r = _T.assert_false(P.should_drop(0, 0.99), "a roll of 0.99 does not drop")
	if r != "":
		return r
	# The boundary itself: BASE_DROP_CHANCE is exclusive, so a roll exactly equal to
	# it must NOT drop, or the effective chance is a hair over the stated one.
	return _T.assert_false(P.should_drop(0, P.BASE_DROP_CHANCE), "chance boundary is exclusive")


## The pity floor is the whole reason drops feel reliable. Without it a 10% roll runs
## PITY_KILLS dry about 19% of the time, which reads as "power-ups are broken".
func test_pity_guarantees_a_drop() -> String:
	var r: String = _T.assert_true(P.should_drop(P.PITY_KILLS, 1.0),
		"pity forces a drop even on the worst possible roll")
	if r != "":
		return r
	r = _T.assert_true(P.should_drop(P.PITY_KILLS + 5, 1.0), "and stays forced beyond it")
	if r != "":
		return r
	return _T.assert_false(P.should_drop(P.PITY_KILLS - 1, 1.0),
		"but not one kill early")


## Pins the cadence the two constants actually produce, because they are only
## meaningful together: the pity floor truncates the geometric distribution, so
## halving BASE_DROP_CHANCE alone barely moves the real rate. Drops arriving faster
## than a buff expires (8s) is what made the buffed state the default state.
func test_drop_cadence_stays_sparse() -> String:
	# Expected kills between drops: sum of P(no drop yet) over the pity window.
	var expected_kills := 0.0
	var survives := 1.0
	for _i in P.PITY_KILLS:
		expected_kills += survives
		survives *= (1.0 - P.BASE_DROP_CHANCE)
	if expected_kills < 6.0:
		return "drops every %.1f kills is too generous (want >= 6)" % expected_kills
	if expected_kills > 12.0:
		return "drops every %.1f kills is too stingy (want <= 12)" % expected_kills
	return ""


func test_stack_of_nothing_is_neutral() -> String:
	var stats: Dictionary = P.stack([])
	for key in stats:
		var r: String = _T.assert_float_eq(float(stats[key]), 1.0, 0.0001, "%s is neutral" % key)
		if r != "":
			return r
	return ""


func test_rage_doubles_damage_without_touching_speed() -> String:
	var stats: Dictionary = P.stack([P.RAGE])
	var r: String = _T.assert_float_eq(float(stats["damage_multiplier"]), 2.0, 0.0001, "rage doubles damage")
	if r != "":
		return r
	return _T.assert_float_eq(float(stats["speed_multiplier"]), 1.0, 0.0001, "rage leaves speed alone")


func test_overclock_raises_speed_and_attack_rate() -> String:
	var stats: Dictionary = P.stack([P.OVERCLOCK])
	var r: String = _T.assert_gt(float(stats["speed_multiplier"]), 1.0, "overclock speeds movement")
	if r != "":
		return r
	return _T.assert_gt(float(stats["attack_speed_multiplier"]), 1.0, "overclock speeds attacks")


## Stacking is multiplicative and order-independent — two buffs held at once must
## compound the same way whichever one was picked up first.
func test_stack_is_multiplicative_and_order_independent() -> String:
	var both: Dictionary = P.stack([P.RAGE, P.OVERCLOCK])
	var reversed: Dictionary = P.stack([P.OVERCLOCK, P.RAGE])
	for key in both:
		var r: String = _T.assert_float_eq(float(both[key]), float(reversed[key]), 0.0001,
			"%s is order-independent" % key)
		if r != "":
			return r
	var expected := float(P.def(P.RAGE)["speed_multiplier"]) * float(P.def(P.OVERCLOCK)["speed_multiplier"])
	return _T.assert_float_eq(float(both["speed_multiplier"]), expected, 0.0001, "speed compounds")


# --- Ramp / shader blend -----------------------------------------------------

## The ramp is what stops a buff popping on and off. It must start at 0, reach full
## in the middle, and return to 0 — anything else and the recolour snaps.
func test_ramp_starts_and_ends_at_zero_and_peaks_in_the_middle() -> String:
	var total := 8.0
	var r: String = _T.assert_float_eq(P.ramp_strength(total, total), 0.0, 0.001, "starts silent")
	if r != "":
		return r
	r = _T.assert_float_eq(P.ramp_strength(total * 0.5, total), 1.0, 0.001, "full strength mid-buff")
	if r != "":
		return r
	return _T.assert_float_eq(P.ramp_strength(0.0, total), 0.0, 0.001, "ends silent")


## Fade-in and fade-out must be the same shape, or a buff would flare on and creep
## off (or vice versa).
func test_ramp_is_symmetric() -> String:
	var total := 8.0
	for i in 20:
		var elapsed := total * float(i) / 20.0
		var into := P.ramp_strength(total - elapsed, total)
		var out_of := P.ramp_strength(elapsed, total)
		var r: String = _T.assert_float_eq(into, out_of, 0.001,
			"ramp at %.2fs in matches %.2fs out" % [elapsed, elapsed])
		if r != "":
			return r
	return ""


func test_ramp_never_leaves_zero_to_one() -> String:
	for total in [0.5, 4.0, 8.0, 30.0]:
		for i in 50:
			var remaining := float(total) * float(i) / 49.0
			var s := P.ramp_strength(remaining, float(total))
			if s < 0.0 or s > 1.0:
				return "ramp_strength(%f, %f) = %f is out of range" % [remaining, total, s]
	return _T.assert_float_eq(P.ramp_strength(1.0, 0.0), 0.0, 0.001, "zero-length buff is silent")


func test_shader_params_are_neutral_with_nothing_active() -> String:
	var params: Dictionary = P.shader_params([])
	var r: String = _T.assert_float_eq(float(params["buff_value"]), 0.0, 0.0001, "no tint")
	if r != "":
		return r
	return _T.assert_float_eq(float(params["buff_pixel_size"]), 0.0, 0.0001, "no dither grid")


func test_shader_params_take_a_single_buffs_colour() -> String:
	var params: Dictionary = P.shader_params([{"id": P.RAGE, "strength": 1.0}])
	var want: Color = P.color(P.RAGE)
	var got: Color = params["buff_color"]
	var r: String = _T.assert_float_eq(got.r, want.r, 0.001, "red channel")
	if r != "":
		return r
	r = _T.assert_float_eq(got.g, want.g, 0.001, "green channel")
	if r != "":
		return r
	return _T.assert_float_eq(float(params["buff_value"]), 1.0, 0.001, "full strength")


## Two buffs must BLEND, not sum. Summing would drive buff_value past 1.0 and wash
## the sprite out to a flat colour the moment a second power-up landed.
func test_two_buffs_blend_without_washing_out() -> String:
	var params: Dictionary = P.shader_params([
		{"id": P.RAGE, "strength": 1.0},
		{"id": P.OVERCLOCK, "strength": 1.0},
	])
	var r: String = _T.assert_float_eq(float(params["buff_value"]), 1.0, 0.001,
		"strength is the strongest single buff, not the sum")
	if r != "":
		return r
	var blended: Color = params["buff_color"]
	var rage: Color = P.color(P.RAGE)
	var over: Color = P.color(P.OVERCLOCK)
	# The blend must land strictly between the two source colours on a channel where
	# they actually differ, which is the observable definition of "crossfaded".
	var lo := minf(rage.b, over.b)
	var hi := maxf(rage.b, over.b)
	return _T.assert_true(blended.b > lo and blended.b < hi,
		"blue channel %f sits between %f and %f" % [blended.b, lo, hi])


## A buff at zero strength (fully ramped out) must contribute nothing, or an expiring
## buff would keep dragging the colour toward itself.
func test_zero_strength_buffs_are_ignored() -> String:
	var params: Dictionary = P.shader_params([
		{"id": P.RAGE, "strength": 1.0},
		{"id": P.OVERCLOCK, "strength": 0.0},
	])
	var got: Color = params["buff_color"]
	var want: Color = P.color(P.RAGE)
	return _T.assert_float_eq(got.b, want.b, 0.001, "the faded-out buff does not tint")


## A pickup must not expire before the player can plausibly reach it, and it must
## start warning before it goes.
func test_pickup_lifetime_leaves_room_to_warn() -> String:
	var r: String = _T.assert_gt(P.PICKUP_LIFETIME, P.PICKUP_BLINK_LEAD,
		"the blink warning fits inside the lifetime")
	if r != "":
		return r
	return _T.assert_gt(P.PICKUP_BLINK_LEAD, 0.0, "there is a warning at all")
