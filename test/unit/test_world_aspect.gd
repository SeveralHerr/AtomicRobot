extends RefCounted

# The window stretches with aspect "expand" (base 1280x800, zoom kept at 2.5): 4:3 and
# 5:4 show more world ABOVE (the camera's bottom is pinned), 16:9 and phones more to
# the SIDES. These pin the world-view rules at every aspect the game ships to, in
# world px: ambient spawns land the same distance past the edge, and the camera never
# rises above the level art.

var _T

const ASPECTS: Array[Vector2i] = [Vector2i(1024, 768), Vector2i(1280, 1024),
	Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(1688, 780)]
const DESIGN := Vector2i(1280, 800)
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const JUMP := preload("res://scripts/states/jump_state.gd")

var _old_size: Vector2i
var _stage: Node2D
var _orphans: Node2D
var _scenes: Array[Node] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func setup() -> void:
	_old_size = _tree().root.size


func teardown() -> void:
	_tree().root.size = _old_size
	if _orphans != null:
		_orphans.free()  # spawned maids were deferred-added here and never entered the tree
		_orphans = null
	if _stage != null:
		_stage.free()
		_stage = null
	for s in _scenes:
		s.free()
	_scenes.clear()


func _resize(size: Vector2i) -> void:
	_tree().root.size = size
	await _tree().process_frame


func _player_at(x: float) -> Player:
	if _stage == null:
		_stage = Node2D.new()
		_tree().root.add_child(_stage)
		_orphans = Node2D.new()
	var p: Player = PLAYER_SCENE.instantiate()
	_stage.add_child(p)
	p.set_process(false)
	p.set_physics_process(false)
	p.global_position = Vector2(x, 0)
	p.camera_2d.make_current()
	return p


func _half_view(p: Player) -> float:
	return p.get_viewport().get_visible_rect().size.x / (2.0 * p.camera_2d.zoom.x)


# --- Ambient spawns ---------------------------------------------------------------

## Every aspect: a spawn lands SPAWN_MARGIN + offset past the visible edge (never on
## screen, same walk-on everywhere) and inside the maid's detection range.
func test_ambient_spawn_lands_a_fixed_margin_past_the_view_edge_at_every_aspect() -> String:
	var p := _player_at(1000.0)
	seed(7)
	for size in ASPECTS:
		await _resize(size)
		var half := _half_view(p)
		for offset in [0.0, -50.0]:
			for i in 4:
				var e: Node2D = EnemySpawner.spawn_enemy(_orphans, p, offset, i == 0)
				var past := absf(e.global_position.x - 1000.0) - half
				var r: String = _T.assert_float_eq(past, EnemySpawner.SPAWN_MARGIN + offset, 0.5,
					"%s offset %d: spawn %.0f px past the edge" % [size, offset, past])
				if r != "":
					return r
				r = _T.assert_true(absf(e.global_position.x - 1000.0) < e.detection_range,
					"%s: spawn %.0f px out is beyond detection range" % [size, absf(e.global_position.x - 1000.0)])
				if r != "":
					return r
	return ""


## The design view must not change: 1280 wide spawns sit where the old
## viewport_width / 3 rule put them.
func test_ambient_spawn_at_the_design_size_matches_the_old_rule() -> String:
	var p := _player_at(500.0)
	await _resize(DESIGN)
	var e: Node2D = EnemySpawner.spawn_enemy(_orphans, p, -50.0, true)
	return _T.assert_float_eq(e.global_position.x, 500.0 + 1280.0 / 3.0 - 50.0, 0.01, "old 1280 spawn x")


## Under an arena lock the camera stops following: spawns key off the VIEW centre,
## so a player pinned at the arena wall can't get a maid spawned on screen.
func test_ambient_spawn_keys_off_the_view_not_a_pinned_player() -> String:
	var p := _player_at(1000.0)
	await _resize(DESIGN)
	# Pinned at the arena's left wall: the view sits 206 px right of the player.
	p.camera_2d.limit_left = 1000 - 50
	p.camera_2d.limit_right = 1000 + 590
	await _tree().process_frame
	var view_right := p.camera_2d.get_screen_center_position().x + _half_view(p)
	var e: Node2D = EnemySpawner.spawn_enemy(_orphans, p, 0.0, true)
	return _T.assert_true(e.global_position.x > view_right,
		"spawn x %.0f is on screen (view right edge %.0f)" % [e.global_position.x, view_right])


# --- Camera tops ------------------------------------------------------------------

func _instance(path: String) -> Node:
	var n: Node = load(path).instantiate()
	_scenes.append(n)
	return n


## Global transform of a node in a scene that is not in the tree. A Parallax2D's
## scroll_offset shifts it (only valid while its vertical scroll_scale is 1).
func _xform(n: Node) -> Transform2D:
	var t := Transform2D.IDENTITY
	var c := n
	while c != null:
		if c is Parallax2D:
			t = Transform2D(0.0, (c as Parallax2D).scroll_offset) * t
		if c is Node2D:
			t = (c as Node2D).transform * t
		c = c.get_parent()
	return t


func _sprite_tops(root: Node, out: Array) -> void:
	if root is CanvasItem and not (root as CanvasItem).visible:
		return
	if root is Sprite2D and (root as Sprite2D).texture != null:
		out.append((_xform(root) * (root as Sprite2D).get_rect()).position.y)
	for c in root.get_children():
		_sprite_tops(c, out)


## Top of the highest background layer: the sky. Every layer that could be it must
## be world-fixed vertically, or its top moves with the camera and this means nothing.
func _sky_top(main: Node) -> float:
	var top := INF
	for layer in main.get_node("Background").get_children():
		if not (layer is Parallax2D) or not layer.visible:
			continue
		if not is_equal_approx(layer.scroll_scale.y, 1.0):
			return -INF
		var tops := []
		_sprite_tops(layer, tops)
		for y in tops:
			top = minf(top, y)
	return top


## Highest surface the player can stand on (top of any static rect it collides with).
func _highest_floor(root: Node, mask: int) -> float:
	var top := INF
	for n in root.find_children("*", "CollisionShape2D", true, false):
		var body := n.get_parent() as StaticBody2D
		var rect := (n as CollisionShape2D).shape as RectangleShape2D
		if body == null or rect == null or body.collision_layer & mask == 0:
			continue
		top = minf(top, (_xform(n) * rect.get_rect()).position.y)
	return top


func _view_height(size: Vector2i, zoom: float) -> float:
	_tree().root.size = size
	return _tree().root.get_visible_rect().size.y / zoom


## 4:3 / 5:4 see more sky; at the top of a jump off the highest roof the view rose
## past the sky layer into the grey clear colour. limit_top stops it at the sky...
func test_street_camera_never_rises_above_the_sky() -> String:
	var main := _instance("res://scenes/main.tscn")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	var sky := _sky_top(main)
	var r: String = _T.assert_true(sky > -INF, "a background layer scrolls vertically")
	if r != "":
		return r
	return _T.assert_true(cam.limit_top >= sky,
		"camera limit_top %d is above the sky's top %.1f" % [cam.limit_top, sky])


## ...and never binds at the 16:10 design size, so that view is unchanged: a jump
## apex off the highest standable surface stays below it.
func test_street_limit_top_never_binds_at_the_design_size() -> String:
	var main := _instance("res://scenes/main.tscn")
	var p: Player = main.get_node("Player")
	var cam: Camera2D = p.camera_2d if p.camera_2d else main.get_node("Player/Camera2D")
	var shape: CollisionShape2D = main.get_node("Player/CollisionShape2D")
	var feet := shape.position.y + shape.shape.get_rect().end.y
	var apex := JUMP.JUMP_VELOCITY * JUMP.JUMP_VELOCITY / (2.0 * p.gravity)
	var floor_top := _highest_floor(main, p.collision_mask)
	var cam_y := floor_top - feet - apex + cam.position.y
	var view_top := cam_y - _view_height(DESIGN, cam.zoom.y) * 0.5
	var r: String = _T.assert_true(floor_top < -500.0, "found the high roofs (top %.0f)" % floor_top)
	if r != "":
		return r
	r = _T.assert_true(view_top >= cam.limit_top,
		"16:10 jump apex view top %.0f is cut by limit_top %d" % [view_top, cam.limit_top])
	if r != "":
		return r
	# The tallest shipped aspect DOES reach it — that's the case the limit exists for.
	var tall_top := cam_y - _view_height(Vector2i(1280, 1024), cam.zoom.y) * 0.5
	return _T.assert_true(tall_top < cam.limit_top, "5:4 apex view top %.0f" % tall_top)


## Boss room: the view at every aspect stays inside the room's art.
func test_boss_room_view_stays_inside_the_room_art_at_every_aspect() -> String:
	var room := _instance("res://scenes/boss_room.tscn")
	var cam: Camera2D = room.get_node("Player/Camera2D")
	var tops := []
	_sprite_tops(room.get_node("Environment"), tops)
	var art_top: float = tops.min()
	var r: String = _T.assert_true(cam.limit_top >= art_top,
		"boss limit_top %d above the room art top %.1f" % [cam.limit_top, art_top])
	if r != "":
		return r
	for size in ASPECTS:
		var h := _view_height(size, cam.zoom.y)
		var w := _tree().root.get_visible_rect().size.x / cam.zoom.x
		r = _T.assert_true(cam.limit_bottom - h >= cam.limit_top - 0.5,
			"%s: %.0f px tall view squeezed between the boss limits" % [size, h])
		if r != "":
			return r
		r = _T.assert_true(cam.limit_right - cam.limit_left >= w,
			"%s: %.0f px wide view is wider than the boss room" % [size, w])
		if r != "":
			return r
	return ""


## Boss reinforcements: the maids appear just past the screen edge at every aspect
## (they popped in ~56 px on screen on a phone), and exactly where they did at 16:10.
func test_boss_maids_appear_just_past_the_edge_at_every_aspect() -> String:
	var room := load("res://scripts/boss_room.gd")
	var r: String = _T.assert_float_eq(room.maid_reach(256.0), 290.0, 0.01, "design reach")
	if r != "":
		return r
	for size in ASPECTS:
		_tree().root.size = size
		var half := _tree().root.get_visible_rect().size.x / (2.0 * 2.5)
		r = _T.assert_float_eq(room.maid_reach(half) - half, 34.0, 0.01, "%s: past the edge" % size)
		if r != "":
			return r
	return ""
