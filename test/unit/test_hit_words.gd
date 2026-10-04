extends RefCounted

## HitWords: one rising comic word per string (hit -> re-punch -> finisher -> KO),
## never a stack. The rank rule is checked over every pair of kinds.

var _T

var _host: Node2D


func setup() -> void:
	ComicPopup.reset_rate_limits()
	_host = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_host)


func teardown() -> void:
	for n in (Engine.get_main_loop() as SceneTree).root.get_children():
		if n is ComicPopup:
			n.free()
	if is_instance_valid(_host):
		_host.free()
	ComicPopup.reset_rate_limits()


func _target() -> Node2D:
	var t := Node2D.new()
	t.position = Vector2(200, 200)
	_host.add_child(t)
	return t


func _popups() -> int:
	var n := 0
	for c in (Engine.get_main_loop() as SceneTree).root.get_children():
		# A retired word is on its RETIRE_FADE way out: it no longer counts.
		if c is ComicPopup and c.life > c.age + ComicPopup.RETIRE_FADE + 0.001:
			n += 1
	return n


func test_kind_for_every_blow() -> String:
	var cases := [
		# killed, finisher, boss, expected
		[false, false, false, &"hit"], [false, true, false, &"finisher"],
		[true, false, false, &"ko"], [true, true, false, &"ko"],
		[false, false, true, &"boss_hit"], [false, true, true, &"finisher"],
		[true, false, true, &""], [true, true, true, &""],
	]
	for c in cases:
		var got := HitWords.kind_for(c[0], c[1], c[2])
		if got != c[3]:
			return "kind_for(killed=%s, finisher=%s, boss=%s) = %s, want %s" % [c[0], c[1], c[2], got, c[3]]
	return ""


## Every (incoming, live) pair: bigger replaces, equal re-punches, smaller stays out.
func test_action_over_every_pair() -> String:
	var live_kinds: Array = HitWords.RANK.keys() + [&"", &"hurt", &"smash"]
	for kind in HitWords.RANK:
		for live in live_kinds:
			var r: int = HitWords.RANK[kind]
			var lr: int = HitWords.RANK.get(live, 0)
			var want := &"spawn" if r > lr else (&"bump" if r == lr else &"none")
			var got := HitWords.action(kind, live)
			if got != want:
				return "action(%s over %s) = %s, want %s" % [kind, live, got, want]
	return _T.assert_eq(HitWords.action(&"", &""), &"none", "no word kind, no word")


func test_every_ranked_kind_is_a_popup_kind() -> String:
	for kind in HitWords.RANK:
		if not ComicPopup.KINDS.has(kind):
			return "HitWords kind %s has no ComicPopup.KINDS entry" % kind
	return ""


func test_ranks_rise_hit_finisher_ko() -> String:
	var r: String = _T.assert_gt(HitWords.RANK[&"finisher"], HitWords.RANK[&"hit"], "finisher outranks hit")
	if r != "":
		return r
	r = _T.assert_gt(HitWords.RANK[&"ko"], HitWords.RANK[&"finisher"], "KO outranks finisher")
	if r != "":
		return r
	r = _T.assert_gt(ComicPopup.KINDS[&"finisher"]["size"], ComicPopup.KINDS[&"hit"]["size"], "finisher word is bigger")
	if r != "":
		return r
	return _T.assert_gt(ComicPopup.KINDS[&"ko"]["size"], ComicPopup.KINDS[&"finisher"]["size"], "KO is the biggest")


## A full string on one maid: never more than one word on screen, the second blow
## re-punches the first word (same card, bigger), the finisher and the KO replace it.
func test_three_hit_string_then_ko_is_one_word_at_a_time() -> String:
	var t := _target()
	var first := HitWords.land(t, false, false)
	var size1 := first.size_mult
	var second := HitWords.land(t, false, false)
	var r: String = _T.assert_true(second == first, "hit 2 re-punches the live word")
	if r != "":
		return r
	r = _T.assert_gt(second.size_mult, size1, "the re-punch grows")
	if r != "":
		return r
	r = _T.assert_eq(_popups(), 1, "one word after two hits")
	if r != "":
		return r
	var fin := HitWords.land(t, false, true)
	r = _T.assert_true(fin != first and fin.kind == &"finisher", "the finisher replaces it")
	if r != "":
		return r
	r = _T.assert_false(first.visible, "the replaced word vanishes at once (a hitstop would freeze its shrink)")
	if r != "":
		return r
	var jab := HitWords.land(t, false, false)
	r = _T.assert_true(jab == null and ComicPopup.live() == fin, "a jab leaves the finisher word alone")
	if r != "":
		return r
	var ko := HitWords.land(t, true, false)
	r = _T.assert_true(ko != null and ko.kind == &"ko" and ComicPopup.live() == ko, "the kill slams KO")
	if r != "":
		return r
	return _T.assert_eq(_popups(), 1, "only the KO left standing (the rest retiring)")


func test_repunch_is_capped() -> String:
	var t := _target()
	var p := HitWords.land(t, false, false)
	for i in 10:
		HitWords.land(t, false, false)
	var cap: float = ComicPopup.KINDS[&"hit"]["size"] * ComicPopup.BUMP_MAX
	return _T.assert_float_eq(p.size_mult, cap, 0.001, "growth stops at BUMP_MAX")


func test_repunch_restarts_life_and_flips_tilt() -> String:
	var t := _target()
	var p := HitWords.land(t, false, false)
	p.age = 0.4
	p.tilt = 0.1
	HitWords.land(t, false, false)
	var r: String = _T.assert_float_eq(p.age, 0.0, 0.0001, "life restarts")
	if r != "":
		return r
	return _T.assert_float_eq(p.tilt, -0.1, 0.0001, "tilt flips")


## The hitstop freezes a word's first frame: combat words must already read there.
func test_combat_words_start_big_enough_to_read_in_the_freeze() -> String:
	for kind in HitWords.RANK:
		var from := float(ComicPopup.KINDS[kind].get("from", 0.35))
		if from < 0.5:
			return "%s pops in from %.2f: a hitstop freezes it that small" % [kind, from]
	return ""


## The word sits clear of the enemy's HP bar at her feet (EnemyHpPips.OFFSET).
func test_biggest_word_clears_the_hp_pips() -> String:
	var biggest := 0.0
	for kind in HitWords.RANK:
		var k: Dictionary = ComicPopup.KINDS[kind]
		biggest = maxf(biggest, float(k["size"]) * maxf(1.0, float(k.get("from", 0.35))))
	var half_h := ComicPopup.CARD_H * 0.5 * ComicPopup.BASE_SCALE * biggest * ComicPopup.BUMP_MAX
	var word_bottom := HitWords.LIFT.y + half_h
	var pips_top := EnemyHpPips.OFFSET.y - EnemyHpPips.SIZE.y * (1.0 + EnemyHpPips.PUNCH)
	return _T.assert_gt(pips_top - word_bottom, 0.0, "word bottom %.1f above pips top %.1f" % [word_bottom, pips_top])


## The card leans away from the attacker so it doesn't sit on the player's head.
func test_word_leans_away_from_the_attacker() -> String:
	var t := _target()
	var right := HitWords.land(t, false, false, t.global_position.x - 50.0)
	var r: String = _T.assert_gt(right._base_pos.x, t.global_position.x, "hit from the left: word right of the target")
	if r != "":
		return r
	var left := HitWords.land(t, false, true, t.global_position.x + 50.0)
	return _T.assert_gt(t.global_position.x, left._base_pos.x, "hit from the right: word left of the target")


## Bigger words rise so their bottom edge stays where a size-1 word's is.
func test_bigger_words_keep_the_same_bottom_edge() -> String:
	var half := ComicPopup.CARD_H * 0.5 * ComicPopup.BASE_SCALE
	for kind in HitWords.RANK:
		var size := float(ComicPopup.KINDS[kind]["size"])
		var bottom := HitWords.anchor(Vector2.ZERO, kind).y + half * size
		if absf(bottom - (HitWords.LIFT.y + half)) > 0.01:
			return "%s bottom edge %.2f, size-1 word's %.2f" % [kind, bottom, HitWords.LIFT.y + half]
	return ""


## The real swing tells land_hit which blow is the string's finisher: mashing on a
## maid on the real Player scene shows hit -> finisher, in that order.
func test_mashed_string_reaches_the_finisher_word() -> String:
	var rig = preload("res://test/unit/player_combat_rig.gd").new()
	await rig.spawn("Ryan")
	rig.maid(40.0)
	var kinds: Array = []
	for i in 150:
		if i % 3 == 0:
			rig.tap("Attack")
		await rig.step(1)
		var live := ComicPopup.live()
		var k: StringName = live.kind if live != null else &""
		if k != &"" and (kinds.is_empty() or kinds[-1] != k):
			kinds.append(k)
	rig.free_all()
	return _T.assert_true(kinds.slice(0, 2) == [&"hit", &"finisher"], "word kinds while mashing: %s" % [kinds])
