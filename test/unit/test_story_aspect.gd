extends RefCounted

## Story and end-of-run screens at every screen shape the game ships to. Stretch
## aspect "expand" grows the 1280x800 canvas on one axis (4:3 cabinet -> 1280x960,
## 16:9 -> 1422x800, landscape phone -> ~1731x800), so anything framed against a fixed
## 1280x800 drifts. Each test sets the real root window size and checks numbers, not
## screenshots.

var _T

const MAIN := "res://scenes/main.tscn"
const BOSS_ROOM := "res://scenes/boss_room.tscn"
const TEST_SAVE := "user://test_scores_story_aspect.cfg"
## Picade 4:3, 5:4, the 16:10 design, 16:9, landscape phone.
const WINDOWS: Array[Vector2i] = [Vector2i(1024, 768), Vector2i(1280, 1024), Vector2i(1280, 800),
	Vector2i(1920, 1080), Vector2i(1688, 780)]

var _root_size: Vector2i
var _saved_path: String
var _nodes: Array[Node] = []
var _level: Node


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func _wait(seconds: float) -> void:
	await _tree().create_timer(seconds, true, false, true).timeout


func setup() -> void:
	_root_size = _tree().root.size
	_saved_path = ScoreSystem.save_path
	ScoreSystem.save_path = TEST_SAVE
	ScoreSystem.clear_records()


func teardown() -> void:
	Input.action_release(&"ui_accept")
	StreetCutscenes.enabled = false
	StreetCutscenes.seen = {}
	for n in _nodes + [_level]:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_level = null
	await _frames()
	MicroCutscene.playing = false
	HudFade.release(_tree(), HudFade.CINEMATIC)
	_tree().paused = false
	NewsCard.active = false
	ScoreSystem.begin_stage("")
	ScoreSystem.running = false
	ScoreSystem.clear_records()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	ScoreSystem.save_path = _saved_path
	ScoreSystem.reload()
	_tree().root.size = _root_size
	await _frames()


## Size the window and return the canvas it now shows.
func _window(size: Vector2i) -> Vector2:
	_tree().root.size = size
	await _frames()
	return _tree().root.get_visible_rect().size


func _opening(size: Vector2i) -> MicroCutscene:
	await _window(size)
	StreetCutscenes.enabled = true
	StreetCutscenes.seen = {}
	_level = (load(MAIN) as PackedScene).instantiate()
	_tree().root.add_child(_level)
	await _frames(3)
	return _level.find_child("MicroCutscene_opening", true, false) as MicroCutscene


func _close_level() -> void:
	_level.queue_free()
	_level = null
	await _frames()
	MicroCutscene.playing = false


## A taller screen shows more above the same road line: every shot (and the glide
## between them) must aim where the camera really looks. Aimed under the road, the
## bottom limit pins the camera while the target keeps moving — the glide stalls.
func test_cutscene_camera_aims_where_it_looks_at_every_aspect() -> String:
	for size in WINDOWS:
		var scene := await _opening(size)
		if scene == null:
			return "%s: no opening" % size
		var cam := scene.camera()
		for i in 12:
			await _wait(0.25)
			var aimed := cam.global_position
			var shown := cam.get_screen_center_position() - cam.offset
			if absf(aimed.y - shown.y) > 0.5:
				return "%s: opening aims at y %.1f but shows y %.1f (under the road)" % [size, aimed.y, shown.y]
		await _close_level()
	return ""


## Hand-back: the glide ends exactly where the play camera then shows, at every
## aspect (a 4:3 screen's play camera sits higher under the same bottom limit).
func test_cutscene_hands_back_on_the_play_camera_framing_at_every_aspect() -> String:
	for size in WINDOWS:
		var scene := await _opening(size)
		var player := _level.get_node("Player") as Player
		var at := {}
		scene.finished.connect(func(_s: bool) -> void:
			at["cut"] = scene.camera().global_position
			at["play"] = player.camera_2d.get_screen_center_position())
		await _frames(2)
		Input.action_press(&"ui_accept")
		await _wait(MicroCutscene.SKIP_HOLD + 0.1)
		Input.action_release(&"ui_accept")
		await _wait(MicroCutscene.SKIP_RETURN_TIME + 0.3)
		if at.is_empty():
			return "%s: skip never finished the scene" % size
		if at["cut"].distance_to(at["play"]) > 1.0:
			return "%s: glide ends at %s, play camera shows %s: the hand-off jumps" % [size, at["cut"], at["play"]]
		await _close_level()
	return ""


## The letterbox spans the real screen, and follows it if the window is resized.
func test_letterbox_bars_follow_the_screen() -> String:
	var scene := await _opening(Vector2i(1280, 800))
	await _wait(BossJuice.LETTERBOX_TIME)
	for size in [Vector2i(1024, 768), Vector2i(1920, 1080)]:
		var view := await _window(size)
		await _wait(BossJuice.LETTERBOX_TIME)
		for bar: ColorRect in scene._bars:
			if absf(bar.size.x - view.x) > 0.5:
				return "%s: bar %.0f wide on a %.0f screen" % [size, bar.size.x, view.x]
		var bottom: ColorRect = scene._bars[1]
		var r: String = _T.assert_float_eq(bottom.position.y + bottom.size.y, view.y, 0.5, "%s: bottom bar sits on the screen's bottom edge" % size)
		if r != "":
			return r
	return ""


## HOLD TO SKIP sits the same distance in from the right edge on every screen.
func test_skip_prompt_hugs_the_right_edge() -> String:
	var inset := -1.0
	for size in WINDOWS:
		var view := await _window(size)
		var layer := CanvasLayer.new()
		_tree().root.add_child(layer)
		_nodes.append(layer)
		var prompt := SkipPrompt.new()
		layer.add_child(prompt)
		await _frames(2)
		var label := prompt.get_child(0) as Control
		var gap := view.x - label.get_global_rect().end.x
		layer.free()
		_nodes.clear()
		if inset < 0.0:
			inset = gap
		elif absf(gap - inset) > 0.5:
			return "%s: HOLD TO SKIP is %.0fpx in from the right edge, %.0fpx at %s" % [size, gap, inset, WINDOWS[0]]
	return ""


## The paper folds off the bottom of a tall screen as far as it does at 16:10.
func test_paper_folds_as_far_down_on_a_tall_screen() -> String:
	var ratios := []
	for size in [Vector2i(1280, 800), Vector2i(1280, 1024), Vector2i(1024, 768)]:
		var view := await _window(size)
		var card := NewsCard.new()
		_tree().root.add_child(card)
		_nodes.append(card)
		card.open("HEADLINE", null, false)
		await _frames(2)
		var from := card.card.position.y
		card.close()
		await _wait(NewsCard.FOLD_SECONDS + 0.1)
		ratios.append((card.card.position.y - from) / view.y)
		card.free()
		_nodes.clear()
	for i in ratios.size():
		if absf(ratios[i] - ratios[0]) > 0.01:
			return "fold drops %.2f of the screen's height on a tall screen, %.2f at 16:10: %s" % [ratios[i], ratios[0], ratios]
	return ""


## The end card is centred and inside the screen, its backdrop covers all of it,
## and it draws above the score HUD — at every aspect.
func test_end_card_centres_and_dims_the_whole_screen_at_every_aspect() -> String:
	for size in WINDOWS:
		var view := await _window(size)
		var level: Node = (load(BOSS_ROOM) as PackedScene).instantiate()
		_tree().root.add_child(level)
		_nodes.append(level)
		await _frames()
		ScoreSystem.current_scene_path = BOSS_ROOM
		ScoreSystem.begin_stage(BOSS_ROOM)
		ScoreSystem.score = 26400
		var card := level.get_node("UI/EndCard") as EndCard
		Globals.boss_death.emit()
		await _frames(4)
		# The tilt wrapper (EndCard.tilted): the card itself is rotated about its centre.
		var rect := (card.find_child("Card", true, false).get_parent() as Control).get_global_rect()
		var screen := Rect2(Vector2.ZERO, view)
		if not screen.encloses(rect.grow(-12)):
			return "%s: card %s spills off the %s screen" % [size, rect, view]
		if rect.get_center().distance_to(view * 0.5) > 8.0:
			return "%s: card centre %s, screen centre %s" % [size, rect.get_center(), view * 0.5]
		var dim := (card.get_node("Dim") as Control).get_global_rect()
		if not dim.encloses(screen):
			return "%s: backdrop %s leaves part of the %s screen undimmed" % [size, dim, view]
		var hud: Node = (load("res://scenes/score_ui.tscn") as PackedScene).instantiate()
		var hud_layer: int = hud.layer
		hud.free()
		var r: String = _T.assert_gt(card.get_parent().layer, hud_layer, "level UI (card) layer above the score HUD")
		if r != "":
			return r
		level.free()
		_nodes.clear()
		ScoreSystem.begin_stage("")
	return ""


## 16:10 must look exactly as before the aspect work: the derived positions land on
## the old hard-coded numbers there.
func test_16_10_layout_is_unchanged() -> String:
	var view := await _window(Vector2i(1280, 800))
	var layer := CanvasLayer.new()
	_tree().root.add_child(layer)
	_nodes.append(layer)
	var prompt := SkipPrompt.new()
	layer.add_child(prompt)
	await _frames(2)
	var r: String = _T.assert_eq(prompt.centre(), Vector2(1196, 84), "HOLD TO SKIP ring where it was")
	if r == "":
		r = _T.assert_float_eq(NewsCard.FOLD_DROP * view.y, 640.0, 0.001, "paper fold drop")
	if r == "":
		for id: String in CutsceneShots.SCENES:
			for s: Dictionary in CutsceneShots.scene(id)["shots"]:
				if CutsceneShots.clamp_center(s["at"], s["zoom"], view) != s["at"]:
					return "%s shot %s re-aimed at 16:10" % [id, s["at"]]
	return r


## A taller screen shows more sky: on every shot, the part showing under the top bar
## must stay inside the street's art (main.tscn's play camera limit_top = the sky
## layer's top). The 130px bar hides the strip above it.
func test_every_shot_stays_inside_the_sky_at_every_aspect() -> String:
	var main: Node = (load(MAIN) as PackedScene).instantiate()
	var sky_top := float((main.get_node("Player/Camera2D") as Camera2D).limit_top)
	main.free()
	for size in WINDOWS:
		var view := await _window(size)
		for id: String in CutsceneShots.SCENES:
			for s: Dictionary in CutsceneShots.scene(id)["shots"]:
				var z: float = s["zoom"]
				var at := CutsceneShots.clamp_center(s["at"], z, view)
				var top := at.y - CutsceneShots.half_view(z, view).y + MicroCutscene.TOP_BAR / z
				if top < sky_top:
					return "%s: %s shot %s shows y %.0f, above the sky's top %.0f" % [size, id, s["at"], top, sky_top]
	return ""
