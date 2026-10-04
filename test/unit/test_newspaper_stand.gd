extends RefCounted

# Newspaper stands (scripts/interactive_mailbox.gd). Each stand used to pick
# randi() % 5 on its own, so a run past all five stands showed the same headline
# twice. They now draw from one shuffle bag, and reading a stand is a secret
# (Globals.secret_found "news"), reported once per stand.

var _T

const STAND_SCENE := preload("res://scenes/interactive_mailbox.tscn")

var _nodes: Array[Node] = []
var _found: Array = []


func setup() -> void:
	_found.clear()
	Globals.secret_found.connect(_on_secret)


func teardown() -> void:
	Globals.secret_found.disconnect(_on_secret)
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _on_secret(kind: String, id: String) -> void:
	_found.append([kind, id])


func _stands(n: int) -> Array:
	var out := []
	for i in n:
		var s: Node = STAND_SCENE.instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(s)
		_nodes.append(s)
		out.append(s)
	return out


func _read_all(stands: Array) -> Array:
	var seen := []
	for s in stands:
		s._show_notification()
		seen.append(s.notification_label.text)
	return seen


func _fresh_run(rng_seed: int) -> void:
	seed(rng_seed)
	var script: Variant = STAND_SCENE.instantiate()
	script.get_script().reset_headline_bag()
	script.free()


func test_five_stands_show_five_different_headlines() -> String:
	for rng_seed in [1, 2, 3, 4, 5]:
		_fresh_run(rng_seed)
		var seen := _read_all(_stands(5))
		var distinct := {}
		for t in seen:
			distinct[t] = true
		if distinct.size() != 5:
			return "seed %d: %d distinct headlines in 5 stands: %s" % [rng_seed, distinct.size(), seen]
	return ""


func test_headline_order_is_seeded() -> String:
	_fresh_run(42)
	var a := _read_all(_stands(5))
	_fresh_run(42)
	var b := _read_all(_stands(5))
	return _T.assert_eq(b, a, "same seed, same headlines (autoplay replays)")


func test_reading_a_stand_reports_one_news_secret() -> String:
	var s: Node = _stands(1)[0]
	s._show_notification()
	s._show_notification()  # read again
	var r: String = _T.assert_eq(_found.size(), 1, "one secret per stand")
	if r != "":
		return r
	return _T.assert_eq(_found[0], ["news", str(s.get_path())], "kind news, id = node path")


func test_each_stand_is_its_own_secret() -> String:
	for s in _stands(2):
		s._show_notification()
	var r: String = _T.assert_eq(_found.size(), 2, "two stands, two secrets")
	if r != "":
		return r
	return _T.assert_true(_found[0][1] != _found[1][1], "ids differ per stand")


# --- Reading: where the paper shows, how long it stays, reading it again ---------
# Player report: the paper popped up right under the score (world-space, above the
# stand, so the HUD column drew over it), expired before it could be read, and could
# never be read again (a 5-minute cooldown).

const NEWS_CARD := preload("res://scripts/ui/news_card.gd")
const SCORE_UI := preload("res://scenes/score_ui.tscn")
## The CRT bezel swallows about this much of every screen edge.
const CRT_EDGE := 40.0
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 800), Vector2i(1688, 780)]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Press Interact the way a player does: aligned to frame start, polled by _process.
func _press_interact() -> void:
	await _tree().process_frame
	Input.action_press("Interact")
	await _tree().process_frame
	await _tree().process_frame
	Input.action_release("Interact")
	await _tree().process_frame


func _near_stand() -> Node:
	var s: Node = _stands(1)[0]
	s.player_in_area = true
	return s


func test_interact_at_the_stand_opens_the_paper() -> String:
	var s := _near_stand()
	await _press_interact()
	var r: String = _T.assert_true(s.is_reading(), "paper up after Interact")
	if r != "":
		return r
	return _T.assert_eq(_found.size(), 1, "first read is the stand's secret")


func test_paper_stays_up_while_the_player_stays_at_the_stand() -> String:
	var s := _near_stand()
	s._show_notification()
	s.advance(60.0)
	return _T.assert_true(s.is_reading(), "a minute at the stand and the paper is still up")


func test_walking_away_keeps_the_paper_for_the_minimum_read() -> String:
	var s := _near_stand()
	s._show_notification()
	s.player_in_area = false
	var need: float = s.min_read_seconds(s.notification_label.text)
	s.advance(need - 0.5)
	var r: String = _T.assert_true(s.is_reading(), "still up before the minimum read time")
	if r != "":
		return r
	s.advance(1.0)
	return _T.assert_false(s.is_reading(), "put away once read and walked off")


func test_min_read_time_scales_with_the_headline() -> String:
	var script: GDScript = STAND_SCENE.instantiate().get_script()
	var short: float = script.min_read_seconds("Robot Parade Scheduled for Friday!")
	var long: float = script.min_read_seconds("Meter Maid Union Demands Heavier Quarters: 'These Ones Don't Leave a Dent'")
	var r: String = _T.assert_true(long > short, "longer headline, longer read (%.1f vs %.1f)" % [long, short])
	if r != "":
		return r
	return _T.assert_true(short >= 3.0, "even a short one stays up 3 s (%.1f)" % short)


func test_interact_again_rereads_the_same_paper_without_new_credit() -> String:
	var s := _near_stand()
	await _press_interact()
	var first: String = s.notification_label.text
	s.player_in_area = false
	s.advance(30.0)
	var r: String = _T.assert_false(s.is_reading(), "precondition: paper put away")
	if r != "":
		return r
	s.player_in_area = true
	await _press_interact()
	r = _T.assert_true(s.is_reading(), "Interact at the stand reads it again")
	if r != "":
		return r
	r = _T.assert_eq(s.notification_label.text, first, "same paper, not the next headline")
	if r != "":
		return r
	return _T.assert_eq(_found.size(), 1, "re-reading claims no second secret")


func test_interact_away_from_the_stand_does_nothing() -> String:
	var s: Node = _stands(1)[0]
	await _press_interact()
	return _T.assert_false(s.is_reading(), "no stand nearby, no paper")


func test_prompt_hides_while_reading_and_returns_after() -> String:
	var s := _near_stand()
	s._refresh_prompt()
	var r: String = _T.assert_true(s.interact_label.visible, "prompt at the stand")
	if r != "":
		return r
	s._show_notification()
	r = _T.assert_false(s.interact_label.visible, "no prompt over an open paper")
	if r != "":
		return r
	s.player_in_area = false
	s.advance(30.0)
	s.player_in_area = true
	s._refresh_prompt()
	return _T.assert_true(s.interact_label.visible, "prompt back: it can be read again")


## The card is screen-space, laid out for real next to the real HUD, at the desktop
## and landscape-phone sizes: inside the CRT-safe area and clear of every HUD row.
func test_paper_card_clears_the_hud_and_the_crt_edge() -> String:
	for window in WINDOWS:
		var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
		var aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect", "keep")
		var canvas := base if aspect == "keep" else Vector2(window) / minf(window.x / base.x, window.y / base.y)
		var vp := SubViewport.new()
		vp.size = Vector2i(canvas)
		_tree().root.add_child(vp)
		var hud: CanvasLayer = SCORE_UI.instantiate()
		vp.add_child(hud)
		hud.set_process(false)
		hud.combo_label.text = "88 HITS!"
		var card: NewsCard = NEWS_CARD.new()
		vp.add_child(card)
		# The longest headline is the tallest card.
		var longest := ""
		for t in STAND_SCENE.instantiate().newspaper_texts:
			if t.length() > longest.length():
				longest = t
		card.open(longest, Vector2.ZERO, false)
		await _tree().process_frame
		await _tree().process_frame
		var rect: Rect2 = card.card.get_global_rect()
		var safe := Rect2(Vector2(CRT_EDGE, CRT_EDGE), canvas - Vector2(CRT_EDGE, CRT_EDGE) * 2.0)
		var rows: Array = []
		for row: Control in hud.get_node("Hud/Rows").get_children():
			rows.append([row.name, row.get_global_rect()])
		vp.free()
		if not safe.encloses(rect):
			return "%s: paper %s pokes outside the CRT-safe area %s" % [window, rect, safe]
		for row in rows:
			if rect.intersects(row[1]):
				return "%s: paper %s overlaps HUD row %s %s" % [window, rect, row[0], row[1]]
	return ""
