extends RefCounted

## BossRules is the City Council fight's balance table. These pin the shape of the
## fight (three phases, each harder than the last) rather than exact numbers, so a
## tuning pass doesn't have to edit tests — only a change that breaks the ramp does.

var _T


func test_full_health_is_phase_zero() -> String:
	return _T.assert_eq(BossRules.phase_for(BossRules.MAX_HEALTH), 0, "fight opens in phase 0")


func test_phase_starts_at_each_threshold() -> String:
	var m := 100
	for pair in [[67, 0], [66, 1], [34, 1], [33, 2], [1, 2], [0, 2], [-5, 2]]:
		var r: String = _T.assert_eq(BossRules.phase_for(pair[0], m), pair[1], "hp %d/100" % pair[0])
		if r != "":
			return r
	return ""


func test_phases_ramp_up() -> String:
	for i in range(1, BossRules.PHASES.size()):
		var prev := BossRules.params(i - 1)
		var cur := BossRules.params(i)
		var r: String = _T.assert_true(cur["throw_delay"] < prev["throw_delay"], "phase %d throws faster" % i)
		if r == "":
			r = _T.assert_true(cur["burst"] >= prev["burst"], "phase %d bursts no smaller" % i)
		if r == "":
			r = _T.assert_true(cur["drop_count"] >= prev["drop_count"], "phase %d drops no fewer" % i)
		if r != "":
			return r
	return ""


func test_each_later_phase_adds_an_attack() -> String:
	var p1 := BossRules.params(1)
	var p2 := BossRules.params(2)
	var r: String = _T.assert_eq(BossRules.params(0)["drop_count"], 0, "opener has no ceiling drops")
	if r == "":
		r = _T.assert_true(p1["drop_count"] > 0 and p1["maids"] > 0, "phase 1 brings drops and maids")
	if r == "":
		r = _T.assert_true(p2["dash_every"] > 0, "phase 2 brings the charge")
	return r


func test_params_clamp_out_of_range() -> String:
	var r: String = _T.assert_eq(BossRules.params(-1), BossRules.params(0), "below range -> phase 0")
	if r == "":
		r = _T.assert_eq(BossRules.params(99), BossRules.params(2), "above range -> last phase")
	return r


func test_every_phase_has_a_banner() -> String:
	for p in BossRules.PHASES:
		var r: String = _T.assert_true(p["title"] != "" and p["sub"] != "" and p["line"] != "", "title + sub + line")
		if r != "":
			return r
	return ""


func test_drops_keep_a_gap_and_stay_in_bounds() -> String:
	var rng := RandomNumberGenerator.new()
	for s in 50:
		rng.seed = s
		for count in [1, 3, 4, 9]:
			var xs := BossRules.drop_xs(count, -400.0, 400.0, rng)
			var r: String = _T.assert_true(xs.size() >= 1 and xs.size() <= count, "count %d -> %d" % [count, xs.size()])
			if r != "":
				return r
			for i in xs.size():
				r = _T.assert_true(xs[i] >= -400.0 and xs[i] <= 400.0, "x %.1f in bounds" % xs[i])
				if r == "" and i > 0:
					r = _T.assert_true(xs[i] - xs[i - 1] >= BossRules.DROP_MIN_GAP - 0.01,
						"gap %.1f >= min" % (xs[i] - xs[i - 1]))
				if r != "":
					return r
	return ""


func test_drops_never_fill_a_narrow_room() -> String:
	var rng := RandomNumberGenerator.new()
	var xs := BossRules.drop_xs(4, 0.0, BossRules.DROP_MIN_GAP * 1.5, rng)
	return _T.assert_eq(xs.size(), 1, "a span under two gaps wide gets one drop")


func test_empty_span_gets_no_drops() -> String:
	var rng := RandomNumberGenerator.new()
	return _T.assert_eq(BossRules.drop_xs(3, 10.0, 10.0, rng).size(), 0, "zero-width span")
