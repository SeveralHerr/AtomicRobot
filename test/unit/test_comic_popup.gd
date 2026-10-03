extends RefCounted

## ComicPopup: spawn, lifetime, rate limit, word pools, one-word-at-a-time, the
## pinball curves it is ported from, and the hooks into combat.

var _T

var _host: Node2D


func setup() -> void:
	ComicPopup.reset_rate_limits()
	_host = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_host)


func teardown() -> void:
	Engine.time_scale = 1.0
	var live := ComicPopup.live()
	if live != null:
		live.free()
	if is_instance_valid(_host):
		_host.free()
	ComicPopup.reset_rate_limits()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_spawn_adds_popup_to_tree() -> String:
	var p := ComicPopup.spawn(_host, Vector2(100, 100), &"hit")
	var r: String = _T.assert_true(p != null, "spawn returns a popup")
	if r != "":
		return r
	r = _T.assert_true(p.is_inside_tree(), "popup is in the tree")
	if r != "":
		return r
	return _T.assert_true(p.get_parent() != _host, "popup is not parented to the anchor (outlives a freed corpse)")


func test_spawn_outside_tree_returns_null() -> String:
	var loose := Node2D.new()
	var p := ComicPopup.spawn(loose, Vector2.ZERO, &"hit")
	loose.free()
	return _T.assert_true(p == null, "no tree, no popup")


func test_unknown_kind_returns_null() -> String:
	return _T.assert_true(ComicPopup.spawn(_host, Vector2.ZERO, &"nope") == null, "unknown kind")


func test_popup_frees_itself_after_lifetime() -> String:
	var p := ComicPopup.spawn(_host, Vector2(100, 100), &"hit")
	var ref: WeakRef = weakref(p)
	var life: float = p.life
	Engine.time_scale = 10.0
	var waited := 0.0
	while ref.get_ref() != null and waited < 3.0:
		await _tree().process_frame
		waited += 1.0 / 60.0
	Engine.time_scale = 1.0
	var r: String = _T.assert_true(ref.get_ref() == null, "popup freed itself")
	if r != "":
		return r
	return _T.assert_gt(life, 0.0, "had a positive lifetime")


func test_rate_limit_blocks_spam_then_allows() -> String:
	var r: String = _T.assert_true(ComicPopup.try_acquire(&"hit", 1000), "first hit allowed")
	if r != "":
		return r
	r = _T.assert_false(ComicPopup.try_acquire(&"hit", 1100), "mash 100ms later blocked")
	if r != "":
		return r
	r = _T.assert_true(ComicPopup.try_acquire(&"hurt", 1100), "kinds have separate cooldowns")
	if r != "":
		return r
	var gap := int(float(ComicPopup.KINDS[&"hit"]["cooldown"]) * 1000.0)
	return _T.assert_true(ComicPopup.try_acquire(&"hit", 1000 + gap), "allowed again after cooldown")


func test_spawn_respects_rate_limit() -> String:
	var first := ComicPopup.spawn(_host, Vector2.ZERO, &"hit")
	var second := ComicPopup.spawn(_host, Vector2.ZERO, &"hit")
	var r: String = _T.assert_true(first != null, "first spawns")
	if r != "":
		return r
	return _T.assert_true(second == null, "immediate second hit is rate-limited")


func test_words_come_from_the_kind_pool() -> String:
	for kind in ComicPopup.KINDS:
		var pool: Array = ComicPopup.KINDS[kind]["words"]
		for i in 20:
			var w := ComicPopup.pick_word(kind)
			if not pool.has(w):
				return "%s picked '%s' outside its pool" % [kind, w]
	return ""


func test_spawned_word_matches_kind_and_style() -> String:
	var p := ComicPopup.spawn(_host, Vector2.ZERO, &"hurt")
	var r: String = _T.assert_true(ComicPopup.KINDS[&"hurt"]["words"].has(p.word), "hurt word from hurt pool")
	if r != "":
		return r
	return _T.assert_eq(p.style, ComicPopup.KINDS[&"hurt"]["style"], "style from kind")


func test_new_word_retires_the_live_one() -> String:
	var a := ComicPopup.spawn(_host, Vector2.ZERO, &"hit")
	var b := ComicPopup.spawn(_host, Vector2.ZERO, &"hurt")
	var r: String = _T.assert_true(ComicPopup.live() == b, "newest word is the live one")
	if r != "":
		return r
	r = _T.assert_true(a.life <= a.age + ComicPopup.RETIRE_FADE + 0.001, "old word is fading out fast")
	a.free()
	return r


func test_placement_stays_inside_view_below_hud() -> String:
	var p := ComicPopup.spawn(_host, Vector2(-99999, -99999), &"hit")
	var vp := p.get_viewport()
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var r: String = _T.assert_gte(p.global_position.x, view.position.x, "not off the left edge")
	if r != "":
		return r
	return _T.assert_gt(p.global_position.y, view.position.y + view.size.y * ComicPopup.HUD_BAND, "below the HUD band")


func test_pop_curve_overshoots_then_lands() -> String:
	var peak := 0.0
	for i in 19:
		peak = maxf(peak, ComicPopup.pop_scale(i * 0.01))
	var r: String = _T.assert_gt(peak, 1.05, "pop overshoots past 1")
	if r != "":
		return r
	r = _T.assert_float_eq(ComicPopup.pop_scale(0.0), 0.35, 0.001, "starts small")
	if r != "":
		return r
	return _T.assert_float_eq(ComicPopup.pop_scale(1.0), 1.0, 0.001, "lands on 1")


func test_fade_holds_then_fades() -> String:
	var r: String = _T.assert_float_eq(ComicPopup.fade_alpha(0.1, 1.0), 1.0, 0.001, "holds")
	if r != "":
		return r
	return _T.assert_float_eq(ComicPopup.fade_alpha(1.0, 1.0), 0.0, 0.001, "gone at end of life")


func test_starburst_has_alternating_spikes() -> String:
	var pts := ComicPopup.starburst(14, Vector2.ZERO, 100.0, 50.0, 7)
	var r: String = _T.assert_eq(pts.size(), 28, "2n points")
	if r != "":
		return r
	return _T.assert_gt(pts[0].length(), pts[1].length(), "outer spike beyond inner notch")


func test_player_damage_pops_hurt_word() -> String:
	var player: Player = preload("res://scenes/player.tscn").instantiate()
	_host.add_child(player)
	await _tree().process_frame
	player.god_mode = false
	player.take_damage(1)
	var live := ComicPopup.live()
	var r: String = _T.assert_true(live != null and ComicPopup.KINDS[&"hurt"]["words"].has(live.word), "player hit says OOF")
	player.free()
	return r


## Stand-in enemy: one hit kills it (or not), like Enemy.receive_hit -> die().
class Target:
	extends Node2D
	var is_dead := false
	var dies_on_hit := false
	func receive_hit(_damage: int) -> void:
		is_dead = dies_on_hit


func _hit_target(dies: bool) -> ComicPopup:
	var player: Player = preload("res://scenes/player.tscn").instantiate()
	_host.add_child(player)
	await _tree().process_frame
	var t := Target.new()
	t.dies_on_hit = dies
	_host.add_child(t)
	player.land_hit(t)
	var live := ComicPopup.live()
	player.free()
	return live


func test_landed_hit_pops_a_word() -> String:
	var live := await _hit_target(false)
	return _T.assert_true(live != null and ComicPopup.KINDS[&"hit"]["words"].has(live.word), "a landed hit says POW")


func test_killing_blow_pops_no_word() -> String:
	var live := await _hit_target(true)
	return _T.assert_true(live == null, "no comic word when the enemy dies (got %s)" % live)
