extends RefCounted

# Stretch aspect "expand": the visible canvas is the 1280x800 base grown on one axis
# (4:3 cabinet 1280x960, 5:4 1280x1024, 16:9 1422x800, phone ~1731x800). The in-game
# overlay must stay pinned to its screen edge / centre at every aspect, the CRT must
# cover the whole canvas with square cells, and 16:10 must be exactly as before.

var _T

const SIZES: Array[Vector2i] = [Vector2i(1024, 768), Vector2i(1280, 1024), Vector2i(1280, 800),
	Vector2i(1920, 1080), Vector2i(1688, 780)]
const DESIGN := Vector2i(1280, 800)
const MOBILE := preload("res://scenes/mobile_controls.tscn")
const SCORE_UI := preload("res://scenes/score_ui.tscn")

var _old_size: Vector2i
var _junk: Array[Node] = []


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _view() -> Rect2:
	return _root().get_visible_rect()


func setup() -> void:
	_old_size = _root().size


func teardown() -> void:
	for n in _junk:
		if is_instance_valid(n):
			n.free()
	_junk.clear()
	CRTOverlay.focus = 0.0
	_root().size = _old_size


func _resize(s: Vector2i) -> void:
	_root().size = s
	await (Engine.get_main_loop() as SceneTree).process_frame


## A CanvasLayer on the root holding `node`, freed in teardown.
func _host(node: Node) -> Node:
	var layer := CanvasLayer.new()
	layer.add_child(node)
	_root().add_child(layer)
	_junk.append(layer)
	return node


func _close(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) < 0.5 and a.size.distance_to(b.size) < 0.5


# --- CRT overlay -------------------------------------------------------------------

func test_hud_aspect_crt_covers_the_whole_screen() -> String:
	for s in SIZES:
		await _resize(s)
		var got: Rect2 = CRTOverlay._rect.get_global_rect()
		var r: String = _T.assert_true(_close(got, _view()), "%s: CRT %s vs view %s" % [s, got, _view()])
		if r != "":
			return r
	return ""


## One CRT cell (scanline pitch x grille pitch) is the same square at every aspect,
## for the normal look and the end card's tuned-in grid alike.
func test_hud_aspect_crt_cells_stay_square() -> String:
	for s in SIZES:
		await _resize(s)
		for f in [0.0, 1.0]:
			CRTOverlay.focus = f
			var grid: Vector2 = CRTOverlay._material.get_shader_parameter("resolution")
			var cell: Vector2 = _view().size / grid
			var want: float = float(DESIGN.x) / lerpf(CRTOverlay.resolution.x, CRTOverlay.FOCUS["resolution"].x, f)
			var r: String = _T.assert_true(absf(cell.x - want) < 0.01 and absf(cell.y - want) < 0.01,
				"%s focus %s: cell %s, want %.2f square" % [s, f, cell, want])
			if r != "":
				return r
	return ""


func test_hud_aspect_crt_grid_at_16_10_is_as_exported() -> String:
	await _resize(DESIGN)
	var grid: Vector2 = CRTOverlay._material.get_shader_parameter("resolution")
	return _T.assert_eq(grid, CRTOverlay.resolution, "16:10 grid unchanged")


# --- Touch controls ----------------------------------------------------------------

## Edge each control is pinned to, derived from where it sits at 16:10: left / right
## half, and top / middle / bottom band. The control must keep that edge distance
## (or its offset from the screen centre) at every aspect, and stay on screen.
func _pins(r: Rect2, view: Rect2) -> Vector2:
	var c := r.get_center() / view.size
	var x := r.position.x if c.x < 0.5 else view.end.x - r.end.x
	var y: float
	if c.y < 0.4:
		y = r.position.y
	elif c.y > 0.6:
		y = view.end.y - r.end.y
	else:
		y = r.get_center().y - view.get_center().y
	return Vector2(x, y)


func test_hud_aspect_touch_controls_hug_their_edges() -> String:
	await _resize(DESIGN)
	var ui: Control = _host(MOBILE.instantiate())
	await _resize(DESIGN)
	var controls: Array[Control] = []
	for c in ui.get_children():
		if c is Control:
			controls.append(c)
	var r: String = _T.assert_gt(controls.size(), 5, "joystick + buttons found")
	if r != "":
		return r
	var home := {}
	for c in controls:
		home[c] = _pins(c.get_global_rect(), _view())
	for s in SIZES:
		await _resize(s)
		for c in controls:
			var rect: Rect2 = c.get_global_rect()
			r = _T.assert_true(_view().encloses(rect), "%s: %s %s off screen" % [s, c.name, rect])
			if r != "":
				return r
			# Classify by the 16:10 band, measure the same way at this aspect.
			var got := _pins(rect, _view())
			r = _T.assert_true(got.distance_to(home[c]) < 0.5, "%s: %s pinned %s, was %s" % [s, c.name, got, home[c]])
			if r != "":
				return r
	return ""


# --- Score / combo, boss card and banners --------------------------------------------

func test_hud_aspect_score_stays_top_centre() -> String:
	var ui: CanvasLayer = SCORE_UI.instantiate()
	_root().add_child(ui)
	_junk.append(ui)
	var hud: Control = ui.get_node("Hud")
	for s in SIZES:
		await _resize(s)
		var rect := hud.get_global_rect()
		var r: String = _T.assert_true(absf(rect.get_center().x - _view().get_center().x) < 0.5
			and absf(rect.position.y - 126.0) < 0.5, "%s: score rows at %s" % [s, rect])
		if r != "":
			return r
	return ""


func test_hud_aspect_boss_card_keeps_its_corner() -> String:
	var bar: BossHealthBar = _host(BossHealthBar.new())
	bar._card.position = BossHealthBar.HOME
	await _resize(DESIGN)
	var card: Control = bar._card
	var right := _view().end.x - card.get_global_rect().end.x
	for s in SIZES:
		await _resize(s)
		var rect := card.get_global_rect()
		var r: String = _T.assert_true(_view().encloses(rect)
			and absf(_view().end.x - rect.end.x - right) < 0.5, "%s: boss card %s" % [s, rect])
		if r != "":
			return r
	return ""


func test_hud_aspect_banner_and_letterbox_span_the_screen() -> String:
	var banner: BossBanner = _host(BossBanner.new())
	for s in SIZES:
		await _resize(s)
		var r: String = _T.assert_true(_close(banner.get_global_rect(), _view()), "%s: banner %s" % [s, banner.get_global_rect()])
		if r != "":
			return r
		var bars := BossJuice.letterbox_in(banner.get_parent(), 130.0, 62.0, 0.0)
		for b in bars:
			_junk.append(b)
		r = _T.assert_true(absf(bars[0].size.x - _view().size.x) < 0.5, "%s: letterbox %s" % [s, bars[0].size])
		if r != "":
			return r
	return ""
