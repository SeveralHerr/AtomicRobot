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
	for a in ["Interact", "Attack", "ui_accept", "pause"]:
		Input.action_release(a)
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	# A paper left open pauses the tree for every later test.
	(Engine.get_main_loop() as SceneTree).paused = false
	NewsCard.active = false
	CRTOverlay.reset_focus()


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


# --- Reading: a modal front page ------------------------------------------------
# Player report: with the CRT on the paper was unreadable (a small card in the HUD
# column: mush at the tube's 512x320 grid, its left edge under the bezel curve). It is
# now a big centred front page that pauses the game until a fresh press folds it.

const NEWS_CARD := preload("res://scripts/ui/news_card.gd")
## The CRT bezel swallows about this much of every screen edge.
const CRT_EDGE := 40.0
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 800), Vector2i(1688, 780)]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _real_seconds(s: float) -> void:
	await _tree().create_timer(s, true, false, true).timeout


## Press `action` the way a player does: aligned to frame start, polled by _process.
func _press(action: String = "Interact") -> void:
	await _tree().process_frame
	Input.action_press(action)
	await _tree().process_frame
	await _tree().process_frame
	Input.action_release(action)
	await _tree().process_frame


func _near_stand() -> Node:
	var s: Node = _stands(1)[0]
	s.player_in_area = true
	return s


## Past the arm window without waiting for its timer.
func _arm(s: Node) -> void:
	s._card._arm()


func _fold_done() -> void:
	await _real_seconds(NEWS_CARD.FOLD_SECONDS + 0.1)


func test_interact_at_the_stand_opens_the_paper_and_pauses() -> String:
	var s := _near_stand()
	await _press()
	var r: String = _T.assert_true(s.is_reading(), "paper up after Interact")
	if r != "":
		return r
	r = _T.assert_true(_tree().paused, "the game waits while the player reads")
	if r != "":
		return r
	r = _T.assert_true(s._card.photo.texture != null, "front page has its photo")
	if r != "":
		return r
	return _T.assert_eq(_found.size(), 1, "first read is the stand's secret")


func test_paper_has_no_timeout() -> String:
	var s := _near_stand()
	await _press()
	_arm(s)
	for i in 30:
		await _tree().process_frame
	return _T.assert_true(s.is_reading(), "nobody pressed: still up")


func test_a_press_inside_the_arm_window_is_ignored() -> String:
	var s := _near_stand()
	await _press()
	await _press("Attack")  # mashing through the fight
	return _T.assert_true(s.is_reading(), "a mash right after opening does not fold it")


func test_the_opening_press_still_held_does_not_fold_it() -> String:
	var s := _near_stand()
	await _tree().process_frame
	Input.action_press("Interact")
	await _tree().process_frame
	await _tree().process_frame
	_arm(s)
	for i in 5:
		await _tree().process_frame
	Input.action_release("Interact")
	return _T.assert_true(s.is_reading(), "held from the opening press: not a fresh press")


func test_a_fresh_press_folds_it_and_resumes_the_game() -> String:
	for action in ["Interact", "Attack", "ui_accept"]:
		var s := _near_stand()
		await _press()
		_arm(s)
		await _press(action)
		var r: String = _T.assert_false(s.is_reading(), "%s folds the paper" % action)
		if r != "":
			return r
		await _fold_done()
		r = _T.assert_false(_tree().paused, "game resumes once folded (%s)" % action)
		if r != "":
			return r
		s.player_in_area = false  # walked on: the next stand's Interact is its own
	return ""


func test_pause_key_folds_the_paper_not_the_pause_menu() -> String:
	var s := _near_stand()
	await _press()
	_arm(s)
	await _press("pause")
	var r: String = _T.assert_false(s.is_reading(), "pause folds the paper")
	if r != "":
		return r
	r = _T.assert_false(PauseMenu.visible, "no pause menu on top of the paper")
	if r != "":
		return r
	await _fold_done()
	return _T.assert_false(_tree().paused, "and the game resumes")


func test_freeing_the_stand_mid_read_unpauses() -> String:
	var s := _near_stand()
	await _press()
	s.free()
	var r: String = _T.assert_false(_tree().paused, "never left paused")
	if r != "":
		return r
	return _T.assert_false(NewsCard.active, "pause key handed back to the pause menu")


func test_interact_again_rereads_the_same_paper_without_new_credit() -> String:
	var s := _near_stand()
	await _press()
	var first: String = s.notification_label.text
	_arm(s)
	await _press()
	await _fold_done()
	var r: String = _T.assert_false(s.is_reading(), "precondition: paper put away")
	if r != "":
		return r
	s._reopen_ok = true
	await _press()
	r = _T.assert_true(s.is_reading(), "Interact at the stand reads it again")
	if r != "":
		return r
	r = _T.assert_eq(s.notification_label.text, first, "same paper, not the next headline")
	if r != "":
		return r
	return _T.assert_eq(_found.size(), 1, "re-reading claims no second secret")


## Autoplay caught it: Interact pressed again while the paper folded re-opened it
## the frame the game resumed (three reads of one stand).
func test_a_mash_through_the_fold_does_not_reopen() -> String:
	var s := _near_stand()
	await _press()
	_arm(s)
	await _press()
	await _fold_done()
	await _press()  # the very next press after the game resumes
	var r: String = _T.assert_false(s.is_reading(), "a mash through the fold does not re-open it")
	if r != "":
		return r
	s._reopen_ok = true
	await _press()
	return _T.assert_true(s.is_reading(), "a deliberate press later reads it again")


func test_interact_away_from_the_stand_does_nothing() -> String:
	var s: Node = _stands(1)[0]
	await _press()
	return _T.assert_false(s.is_reading(), "no stand nearby, no paper")


func test_prompt_hides_while_reading_and_returns_after() -> String:
	var s := _near_stand()
	s._refresh_prompt()
	var r: String = _T.assert_true(s.interact_label.visible, "prompt at the stand")
	if r != "":
		return r
	await _press()
	r = _T.assert_false(s.interact_label.visible, "no prompt over an open paper")
	if r != "":
		return r
	_arm(s)
	await _press()
	await _fold_done()
	return _T.assert_true(s.interact_label.visible, "prompt back: it can be read again")


func test_crt_tunes_in_while_reading() -> String:
	var s := _near_stand()
	await _press()
	await _real_seconds(CRTOverlay.TUNE_SECONDS + 0.1)
	# Part way only: full focus wiped scanlines and fringe and read as "CRT off".
	var f := CRTOverlay.focus
	var r: String = _T.assert_true(f > 0.3 and f < 0.9, "tube part-focused for reading (%.2f)" % f)
	if r != "":
		return r
	_arm(s)
	await _press()
	await _real_seconds(CRTOverlay.TUNE_SECONDS + 0.1)
	return _T.assert_true(CRTOverlay.focus < 0.05, "and back to the cabinet look (%.2f)" % CRTOverlay.focus)


## Touch screens: the pad's buttons are paused with the game, so a tap anywhere folds.
func test_a_click_or_tap_folds_it_once_armed() -> String:
	var s := _near_stand()
	await _press()
	await _tap_screen()
	var r: String = _T.assert_true(s.is_reading(), "a tap right away is the mash guard's")
	if r != "":
		return r
	_arm(s)
	await _tree().process_frame
	await _tap_screen()
	return _T.assert_false(s.is_reading(), "a tap once armed folds it")


## A screen touch through the real input pipeline (the tree is paused meanwhile).
func _tap_screen() -> void:
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.pressed = down
		touch.position = Vector2(30, 30)
		Input.parse_input_event(touch)
		await _tree().process_frame


## Round-2 screenshot: the score peeked out half-hidden behind the top of the page.
func test_hud_clears_while_reading_and_returns() -> String:
	var hud := Control.new()
	hud.add_to_group(HudFade.CINEMATIC)
	_tree().root.add_child(hud)
	_nodes.append(hud)
	var s := _near_stand()
	await _press()
	await _real_seconds(0.3)
	var r: String = _T.assert_true(hud.modulate.a < 0.05, "HUD gone under the paper (%.2f)" % hud.modulate.a)
	if r != "":
		return r
	_arm(s)
	await _press()
	await _real_seconds(0.4)
	return _T.assert_true(hud.modulate.a > 0.95, "HUD back after the fold (%.2f)" % hud.modulate.a)


## Every headline gets a front-page photo (derived from the stand's own list).
func test_every_headline_has_a_photo() -> String:
	var stand: Node = STAND_SCENE.instantiate()
	var texts: Array = stand.newspaper_texts
	var script: GDScript = stand.get_script()
	stand.free()
	for t in texts:
		if script.photo_for(t) == null:
			return "no photo for '%s'" % t
	return ""


## Laid out for real at the desktop and landscape-phone sizes: big, centred, and
## inside the CRT-safe area with the longest headline.
func test_paper_is_big_and_inside_the_crt_safe_area() -> String:
	var stand: Node = STAND_SCENE.instantiate()
	var longest := ""
	for t in stand.newspaper_texts:
		if t.length() > longest.length():
			longest = t
	var photo: Texture2D = stand.get_script().photo_for(longest)
	stand.free()
	for window in WINDOWS:
		var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
		var aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect", "keep")
		var canvas := base if aspect == "keep" else Vector2(window) / minf(window.x / base.x, window.y / base.y)
		var vp := SubViewport.new()
		vp.size = Vector2i(canvas)
		_tree().root.add_child(vp)
		var card: NewsCard = NEWS_CARD.new()
		vp.add_child(card)
		card.open(longest, photo, false)
		await _tree().process_frame
		await _tree().process_frame
		var rect: Rect2 = card.card.get_global_rect()
		vp.free()
		var safe := Rect2(Vector2(CRT_EDGE, CRT_EDGE), canvas - Vector2(CRT_EDGE, CRT_EDGE) * 2.0)
		if not safe.encloses(rect):
			return "%s: paper %s pokes outside the CRT-safe area %s" % [window, rect, safe]
		if rect.size.x < canvas.x * 0.6:
			return "%s: paper %s is not big (canvas %s)" % [window, rect, canvas]
		if absf(rect.get_center().x - canvas.x * 0.5) > 8.0:
			return "%s: paper %s is not centred" % [window, rect]
	return ""
