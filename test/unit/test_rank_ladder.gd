extends RefCounted

# The rank ladder on the end card (scripts/ui/rank_ladder.gd). Player report: "my
# best full clear got ~7k but still rank C. What do I need for a better rank?" The
# card now shows every rank's threshold, how far the next one is, and the one
# thing in this run that would have got there.

var _T

const L := preload("res://scripts/ui/rank_ladder.gd")


## A C-rank clear: 7,200 total (the player's ~7k), 5:30, hit 6 times, 3 of 7 secrets.
func _run(total: int = 7200) -> Dictionary:
	return {"won": true, "total": total, "rank": ScoreRules.rank_for(total), "seconds": 330.0,
		"perfect": false, "no_damage_bonus": 1000, "secrets": {"wall": 1, "news": 2},
		"secret_totals": {"wall": 2, "news": 5}}


func test_next_line_names_the_next_rank_and_the_gap() -> String:
	return _T.assert_eq(L.next_text(7200), "+800 FOR B (8,000)", "gap to B")


func test_top_rank_says_so() -> String:
	return _T.assert_eq(L.next_text(25000), "TOP RANK!", "nothing above S")


func test_tip_prefers_secrets_when_they_cover_the_gap() -> String:
	# 800 short, 4 secrets unfound at 250 each: 4 cover it.
	return _T.assert_eq(L.tip_text(_run()), "FIND 4 MORE SECRETS", "secrets first")


func test_tip_then_no_hits() -> String:
	var run := _run()
	run["secrets"] = {"wall": 2, "news": 5}  # all found
	# hit 6 times: a flawless clear pays 3,000 instead of 1,000 - covers the 800
	return _T.assert_eq(L.tip_text(run), "CLEAR IT WITHOUT A HIT", "flawless next")


func test_tip_falls_back_to_time() -> String:
	var run := _run()
	run["secrets"] = {"wall": 2, "news": 5}  # all found
	run["no_damage_bonus"] = ScoreRules.PERFECT_BONUS
	run["perfect"] = true
	# 800 / 15 per second -> 54 s faster
	return _T.assert_eq(L.tip_text(run), "FINISH 0:54 FASTER", "time next")


func test_tip_time_over_par_names_the_target() -> String:
	var run := _run(1600)  # 3,400 short of C: more than a flawless clear pays
	run["secrets"] = {"wall": 2, "news": 5}
	run["seconds"] = 430.0  # over par: time only pays under 7:00
	# 3400 / 15 = 227 s under par -> 3:13
	return _T.assert_eq(L.tip_text(run), "FINISH UNDER 3:13", "time below par")


func test_tip_skips_an_unrealistic_time() -> String:
	var run := _run(15000)  # 5,000 short of S
	run["secrets"] = {"wall": 2, "news": 5}
	run["seconds"] = 430.0  # would need 1:26, faster than FASTEST_SECONDS
	return _T.assert_eq(L.tip_text(run), "CHAIN COMBOS: KILLS PAY UP TO x8", "no 2-minute promise")


func test_tip_combo_when_nothing_else_covers_it() -> String:
	var run := _run(100)
	run["secrets"] = {"wall": 2, "news": 5}
	run["seconds"] = 900.0
	return _T.assert_eq(L.tip_text(run), "CHAIN COMBOS: KILLS PAY UP TO x8", "fallback")


func test_no_tip_at_the_top() -> String:
	return _T.assert_eq(L.tip_text(_run(30000)), "", "S needs no tip")


## Review round 3: two hint lines under the score were noise again. One line: the
## concrete thing to do and the rank it buys...
func test_line_is_the_tip_and_its_rank_on_one_line() -> String:
	return _T.assert_eq(L.line_text(_run(), true), "FIND 4 MORE SECRETS FOR B", "one actionable line")


## ...or, when only the generic combo tip is left, just the gap.
func test_line_is_the_gap_when_only_the_combo_tip_is_left() -> String:
	var run := _run(15000)
	run["secrets"] = {"wall": 2, "news": 5}
	run["seconds"] = 430.0
	return _T.assert_eq(L.line_text(run, true), "+5,000 FOR S (20,000)", "gap, no combo tip")


func test_line_at_the_top_rank() -> String:
	return _T.assert_eq(L.line_text(_run(30000), true), "TOP RANK!", "top rank")


func test_line_on_a_death_has_no_tip() -> String:
	return _T.assert_eq(L.line_text({"total": 1500, "rank": ""}, false), "CLEAR THE BOSS TO GET RANKED", "death")


func test_death_says_how_to_get_ranked() -> String:
	return _T.assert_eq(L.next_text(1500, false), "CLEAR THE BOSS TO GET RANKED", "no rank on a death")


## Built for real: the card line is the gap plus the tip, no chip row.
func test_ladder_shows_one_line() -> String:
	var ladder: RankLadder = L.new()
	ladder.show_run(_run(), true)
	var r: String = _T.assert_eq(ladder.get_child_count(), 1, "only the hint line")
	if r == "":
		r = _T.assert_eq(ladder.next_label.text, L.line_text(_run(), true), "line text")
	ladder.free()
	return r


## The tallest card (unlock stamp, full breakdown, ladder, tip, badge) laid out for
## real must fit the CRT-safe area (the bezel eats ~40 px of every edge), in both
## right-column states: entering initials, then the list with the buttons.
func _card_bounds(listing: bool) -> Rect2:
	var tree := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 800)
	tree.root.add_child(vp)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(ui)
	var card := EndCard.new()
	ui.add_child(card)
	var run := _run()
	run.merge({"fight_score": 5600, "street_score": 3900, "boss_score": 1700, "bonus": 3100,
		"time_bonus": 1350, "secret_bonus": 750, "unlocks": ["Robot"], "slot": 0})
	card.summary.show_run(run, true)
	var rows: Array = []
	for i in HighScoreTable.SIZE:
		rows.append(HighScoreTable.make_entry("AAA", 100000 - i))
	card.entry.visible = not listing
	card.table.visible = listing
	if listing:
		card.table.show_entries(rows, 0)
	card._buttons.visible = listing
	card.show()
	for i in 3:
		await tree.process_frame
	# The tilted card's bounds, from its rotated corners.
	var inner: Control = card._card
	var xf := inner.get_global_transform()
	var rect := Rect2(xf * Vector2.ZERO, Vector2.ZERO)
	for c in [Vector2(inner.size.x, 0), inner.size, Vector2(0, inner.size.y)]:
		rect = rect.expand(xf * c)
	vp.free()
	return rect


func test_tallest_card_fits_inside_the_crt_safe_area() -> String:
	for listing in [false, true]:
		var rect: Rect2 = await _card_bounds(listing)
		if rect.size.y > 720.0 or rect.size.x > 1200.0:
			return "card %s (listing=%s) is bigger than the 1200x720 CRT-safe area" % [rect.size, listing]
	return ""


## Mutation survivor: an under-par run whose gap needs an impossible time gets the
## combo tip, not "FINISH 3:54 FASTER" on a 5:00 run.
func test_tip_skips_an_unrealistic_saving_under_par() -> String:
	var run := _run(1500)  # 3,500 short of C -> 234 s
	run["secrets"] = {"wall": 2, "news": 5}
	run["no_damage_bonus"] = ScoreRules.PERFECT_BONUS
	run["seconds"] = 300.0  # would need 1:06
	return _T.assert_eq(L.tip_text(run), L.COMBO_TIP, "no 1-minute promise")
