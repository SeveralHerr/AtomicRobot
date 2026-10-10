extends RefCounted

## Menus at every screen shape (stretch aspect "expand": the visible rect is 1280x800
## grown on one axis). Each screen is mounted in a SubViewport sized like the canvas a
## real window gets, and its layout is checked as numbers: backdrops cover the rect,
## content stays centred and on screen, 16:10 is unchanged, taps still land.

var _T

const SELECT := preload("res://scenes/character_select.tscn")
const TITLE := preload("res://scenes/startscreen.tscn")
const CONTROLS := preload("res://scenes/controls_splash.tscn")
const PAUSE := preload("res://scenes/pause_menu.tscn")
const StartScript := preload("res://scripts/startscreen.gd")
const SWAY := preload("res://scripts/sway.gd")
const TRANSITION := preload("res://scripts/autoload/transition.gd")
const DESIGN := Vector2(1280, 800)
## Canvas sizes for 4:3 (Picade 1024x768), 5:4, 16:10, 16:9, landscape phone 1688x780.
const VIEWS: Array[Vector2i] = [Vector2i(1280, 960), Vector2i(1280, 1024), Vector2i(1280, 800),
		Vector2i(1422, 800), Vector2i(1731, 800)]

class StubSelect:
	extends "res://scripts/character_select.gd"
	func _init() -> void:
		accept_grace = 0.0
	func start_run() -> void:
		pass


var _vp: SubViewport
var _saved_character: String
var _saved_splash: bool


func setup() -> void:
	_saved_character = Globals.selected_character
	_saved_splash = StartScript.splash_played
	StartScript.splash_played = true  # the title's own splash is tested on its own


func teardown() -> void:
	Globals.selected_character = _saved_character
	StartScript.splash_played = _saved_splash
	if is_instance_valid(_vp):
		_vp.free()
	_vp = null


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n := 3) -> void:
	for i in n:
		await _tree().process_frame


func _mount(node: Node, view: Vector2i, settle := 3) -> Node:
	if is_instance_valid(_vp):
		_vp.free()
	_vp = SubViewport.new()
	_vp.size = view
	_tree().root.add_child(_vp)
	_vp.add_child(node)
	await _frames(settle)
	return node


func _backdrop(scene: Node) -> TextureRect:
	for c in scene.find_children("*", "TextureRect", true, false):
		if c.get_script() == SWAY:
			return c
	return null


## The art covers the whole rect at both ends of its sway, and keeps 16:10 proportions.
func _covers(bg: TextureRect, view: Vector2, what: String) -> String:
	if bg == null:
		return "%s: no swaying backdrop" % what
	# Both ends of the sway (an art without a `sway` offset is checked where it is).
	var ends: Array = [-bg.sway_amount, bg.sway_amount] if "sway" in bg else [0.0]
	for s in ends:
		if "sway" in bg:
			bg.sway = s
		var r := bg.get_global_rect()
		if not r.encloses(Rect2(Vector2.ZERO, view)):
			return "%s at %s sway %s: art %s leaves a gap" % [what, view, s, r]
	return _T.assert_float_eq(bg.size.x / bg.size.y, DESIGN.x / DESIGN.y, 0.001, "%s art aspect" % what)


func test_aspect_backdrops_cover_every_aspect() -> String:
	for view in VIEWS:
		for pair in [["title", TITLE], ["controls", CONTROLS], ["select", SELECT]]:
			var scene: Node = await _mount(pair[1].instantiate(), view)
			var r := _covers(_backdrop(scene), Vector2(view), pair[0])
			if r != "":
				return r
	return ""


func test_aspect_backdrop_unchanged_at_16_10() -> String:
	var scene: Node = await _mount(TITLE.instantiate(), Vector2i(1280, 800))
	var bg := _backdrop(scene)
	if "sway" in bg:
		bg.sway = 0.0
	var r: String = _T.assert_float_eq(bg.position.distance_to(Vector2(-42, -2)), 0.0, 1.0,
			"16:10 art spot (got %s)" % bg.position)
	if r != "":
		return r
	return _T.assert_eq(bg.size, DESIGN, "16:10 art size")


func test_aspect_backdrop_refits_on_resize() -> String:
	var scene: Node = await _mount(CONTROLS.instantiate(), Vector2i(1280, 800))
	_vp.size = Vector2i(1280, 1024)
	await _frames()
	return _covers(_backdrop(scene), Vector2(1280, 1024), "controls after resize")


func _select(view: Vector2i, settle := 3) -> Node:
	Globals.selected_character = "Ryan"
	var s := SELECT.instantiate()
	s.set_script(StubSelect)
	return await _mount(s, view, settle)


func _inside(c: Control, view: Vector2, what: String) -> String:
	var r := c.get_global_rect()
	if not Rect2(Vector2.ZERO, view).encloses(r):
		return "%s %s off the %s screen" % [what, r, view]
	return ""


func test_aspect_select_stage_centred_at_every_aspect() -> String:
	for view in VIEWS:
		var s: Node = await _select(view)
		await _tree().create_timer(1.2).timeout  # roster drop-in and info slide land
		var v := Vector2(view)
		var roster: Control = s.find_child("Roster", true, false)
		var footer: Control = s.find_child("Footer", true, false)
		var r: String = _T.assert_float_eq(roster.get_global_rect().get_center().x, v.x / 2.0, 0.5,
				"roster centred at %s" % v)
		if r != "":
			return r
		r = _T.assert_float_eq(footer.get_global_rect().get_center().x, v.x / 2.0, 0.5, "footer centred at %s" % v)
		if r != "":
			return r
		for c in [roster, footer, s.info]:
			r = _inside(c, v, c.name)
			if r != "":
				return r
		# The title is a full-width, wobbling label: its text is centred, not its box inside.
		r = _T.assert_float_eq(s.title.get_global_rect().get_center().x, v.x / 2.0, 2.5, "title centred at %s" % v)
		if r != "":
			return r
		# The 1280x800 stage sits in the middle of the extra room.
		r = _T.assert_eq(roster.get_global_rect().position, Vector2(145, 556) + ((v - DESIGN) / 2.0).floor(),
				"roster spot at %s" % v)
		if r != "":
			return r
	return ""


func test_aspect_select_info_card_enters_from_off_screen() -> String:
	for view in VIEWS:
		var s: Node = await _select(view, 0)  # read the start spot before the slide runs
		var x: float = s.info.get_global_rect().position.x
		var r: String = _T.assert_gte(x, float(view.x), "info card starts past the right edge at %s" % view)
		if r != "":
			return r
	return ""


func test_aspect_select_recentres_on_resize() -> String:
	var s: Node = await _select(Vector2i(1280, 800))
	_vp.size = Vector2i(1731, 800)
	await _frames()
	var roster: Control = s.find_child("Roster", true, false)
	var r: String = _T.assert_float_eq(roster.get_global_rect().get_center().x, 1731 / 2.0, 0.5, "roster after resize")
	if r != "":
		return r
	return _covers(_backdrop(s), Vector2(1731, 800), "select after resize")


## A real finger tap pushed into the expanded viewport: first previews, second picks.
func _tap(c: Control) -> void:
	var at: Vector2 = c.get_global_transform_with_canvas() * (c.size / 2.0)
	for pressed in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = at
		t.pressed = pressed
		_vp.push_input(t, true)
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		m.position = at
		m.global_position = at
		m.pressed = pressed
		m.device = InputEvent.DEVICE_ID_EMULATION
		_vp.push_input(m, true)
		await _frames(6 if pressed else 2)


func test_aspect_select_taps_land_on_wide_and_tall_screens() -> String:
	for view in [Vector2i(1731, 800), Vector2i(1280, 1024)]:
		var s: Node = await _select(view)
		await _tree().create_timer(1.2).timeout
		var cass: Control = s.card_for("Cass")
		await _tap(cass)
		var r: String = _T.assert_true(cass.has_focus(), "first tap focuses Cass at %s" % view)
		if r != "":
			return r
		await _tap(cass)
		r = _T.assert_eq(Globals.selected_character, "Cass", "second tap picks at %s" % view)
		if r != "":
			return r
	return ""


## The logo box the splash used at 16:10, kept whole at every other shape.
func test_aspect_splash_logo_framed_like_16_10() -> String:
	var ref := Rect2()
	for view in [Vector2i(1280, 800)] + VIEWS:
		var splash: JamcraftSplash = await _mount(JamcraftSplash.new(), view)
		var logo: Control = splash.find_child("Logo", true, false)
		# Unscaled: the pop-in scales the logo about its centre.
		var r := Rect2((logo.get_parent() as Control).global_position + logo.position, logo.size)
		if ref.size == Vector2.ZERO:
			ref = r
			continue
		var res: String = _T.assert_eq(r.size, ref.size, "logo size at %s" % view)
		if res != "":
			return res
		res = _T.assert_float_eq(r.get_center().distance_to(Vector2(view) / 2.0), 0.0, 0.01,
				"logo centred at %s (got %s)" % [view, r.get_center()])
		if res != "":
			return res
		# The box clips the art, so its 2px border never draws as a seam on the black.
		res = _T.assert_true(logo.get_parent().clip_contents, "logo box clips at %s" % view)
		if res != "":
			return res
		var bg: Control = splash.find_child("Background", true, false)
		res = _T.assert_eq(bg.get_global_rect(), Rect2(Vector2.ZERO, Vector2(view)), "splash black at %s" % view)
		if res != "":
			return res
	return ""


func test_aspect_pause_and_fade_fill_every_aspect() -> String:
	for view in VIEWS:
		var v := Vector2(view)
		var full := Rect2(Vector2.ZERO, v)
		var pm: CanvasLayer = await _mount(PAUSE.instantiate(), view)
		pm.set_process(false)  # a stray pause press must not toggle the real tree
		pm.visible = true
		await _frames()
		for n in ["Background", "Dim"]:
			var r: String = _T.assert_true(pm.get_node(n).get_global_rect().encloses(full), "%s covers %s" % [n, v])
			if r != "":
				return r
		var panel: Control = pm.get_node("CenterContainer/Panel")
		var r1: String = _T.assert_float_eq(panel.get_global_rect().get_center().distance_to(v / 2.0), 0.0, 1.0,
				"pause panel centred at %s" % v)
		if r1 != "":
			return r1
		var tr: CanvasLayer = await _mount(TRANSITION.new(), view)
		var fade: Control = tr.get_node("Fade")
		var r2: String = _T.assert_true(fade.get_global_rect().encloses(full), "fade covers %s" % v)
		if r2 != "":
			return r2
	return ""


func test_aspect_title_and_controls_content_centred() -> String:
	for view in VIEWS:
		var v := Vector2(view)
		var title: Node = await _mount(TITLE.instantiate(), view)
		var logo: Control = title.get_node("MarginContainer")
		var r: String = _T.assert_float_eq(logo.get_global_rect().get_center().distance_to(v / 2.0), 0.0, 1.0,
				"title logo centred at %s" % v)
		if r != "":
			return r
		var ctrl: Node = await _mount(CONTROLS.instantiate(), view)
		var box: Control = ctrl.get_node("CenterContainer/VBoxContainer")
		r = _T.assert_float_eq(box.get_global_rect().get_center().distance_to(v / 2.0), 0.0, 1.0,
				"controls list centred at %s" % v)
		if r != "":
			return r
		r = _inside(ctrl.get_node("MarginContainer"), v, "press-any-button line")
		if r != "":
			return r
	return ""
