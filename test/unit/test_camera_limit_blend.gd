extends RefCounted

# Door fights lock the camera to the arena and release it on STREET CLEAR!. The
# limits used to snap, so the view jumped up to 640 screen px in one frame and the
# player read it as their character teleporting. CameraLimitBlend eases them; these
# tests sample the player's SCREEN x every frame across a real lock and release.

var _T

const BLEND := preload("res://scripts/camera_limit_blend.gd")
const ENC_SCENE := preload("res://scenes/building_door_encounter.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
## Screen px the player may appear to move in one 60 fps frame from the camera alone.
## The old snap was ~590; an eased 256 world px pan peaks near 30.
const MAX_FRAME_JUMP := 40.0

var _stage: Node2D
var _enc
var _p: Player
var _cam: Camera2D
var _old_scene: Node
var _old_fps: int


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make() -> void:
	_old_fps = Engine.max_fps
	Engine.max_fps = 60
	_stage = Node2D.new()
	_tree().root.add_child(_stage)
	_old_scene = _tree().current_scene
	_tree().current_scene = _stage
	_p = PLAYER_SCENE.instantiate()
	_stage.add_child(_p)
	_p.set_process(false)
	_p.set_physics_process(false)
	_cam = _p.camera_2d
	_cam.make_current()
	_enc = ENC_SCENE.instantiate()
	_enc.enemy_count = 1
	_enc.arm_seconds = 0.02
	_enc.spawn_interval = 0.01
	_enc.walk_out_seconds = 0.02
	_stage.add_child(_enc)
	_enc.global_position = Vector2(1000, 0)


func teardown() -> void:
	if _stage == null:
		return
	Engine.max_fps = _old_fps
	ScreenShake.stop()
	_tree().current_scene = _old_scene
	for e in _enc._spawned:
		if is_instance_valid(e):
			Globals.release_attack_slot(e)
	await _tree().process_frame
	_stage.free()
	_stage = null


## Player's x on screen with any shake offset taken back out: the shake is a
## separate, deliberate effect, this measures only where the limits put the view.
func _screen_x() -> float:
	return _p.get_global_transform_with_canvas().origin.x + _cam.offset.x * _cam.zoom.x


## Samples screen x for `seconds`, starting from `start` (taken BEFORE the action:
## a limit setter moves the canvas at once, not on the next frame); returns
## [max per-frame jump, last x].
func _sample(seconds: float, start: float) -> Array:
	var last := start
	var worst := absf(_screen_x() - start)
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await _tree().process_frame
		var x := _screen_x()
		worst = maxf(worst, absf(x - last))
		last = x
	return [worst, last]


func _until(cond: Callable, seconds: float = 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func _kill_squad() -> void:
	for e in _enc._spawned:
		if is_instance_valid(e) and not e.is_dead:
			e.is_dead = true
			e.process_mode = Node.PROCESS_MODE_DISABLED


func _centre_x() -> float:
	return _cam.get_viewport_rect().size.x * 0.5


## Lock-in with the player off to one side of the door: the view must ease onto the
## arena, not jump there.
func test_lock_in_eases_the_view_onto_the_arena() -> String:
	_make()
	_p.global_position = Vector2(1000 + 290, 0)
	for i in 3:
		await _tree().process_frame
	var before := _screen_x()
	_enc._on_body_entered(_p)
	var s: Array = await _sample(1.0, before)
	var r: String = _T.assert_true(s[0] <= MAX_FRAME_JUMP,
		"lock-in moved the player %.0f screen px in one frame" % s[0])
	if r != "":
		return r
	# ...and the lock did land: the view stops at the arena's right edge.
	return _T.assert_eq(_cam.limit_right, 1000 + _enc.arena_half_width, "arena limit reached")


## STREET CLEAR! with the player pinned at the arena wall: the camera pans back onto
## the player instead of snapping 600+ px.
func test_street_clear_release_pans_back_to_the_player() -> String:
	_make()
	_p.global_position = Vector2(1000 - 300, 0)
	_enc._on_body_entered(_p)
	await _until(func(): return not _enc._spawning and _enc._spawned.size() == 1)
	await _sample(0.8, _screen_x())  # lock settles
	var pinned := _screen_x()
	_kill_squad()
	var s: Array = await _sample(1.2, pinned)
	var r: String = _T.assert_true(absf(pinned - _centre_x()) > 300.0,
		"setup: player pinned near the screen edge (x %.0f)" % pinned)
	if r != "":
		return r
	r = _T.assert_true(s[0] <= MAX_FRAME_JUMP,
		"release moved the player %.0f screen px in one frame" % s[0])
	if r != "":
		return r
	return _T.assert_float_eq(s[1], _centre_x(), 2.0, "camera ends centred on the player")


## A lock that starts while the last release is still easing saves the release's
## TARGET, so the next release restores the street's limits, not a half-way view.
func test_lock_saves_the_blend_target_not_the_live_limits() -> String:
	_make()
	_cam.limit_left = -5000
	_cam.limit_right = 5000
	BLEND.blend(_cam, -100, 100, 5.0)
	await _tree().process_frame
	_enc._on_body_entered(_p)
	return _T.assert_eq(Vector2i(_enc._saved_limit_left, _enc._saved_limit_right),
		Vector2i(-100, 100), "saved the in-flight target")


# --- Pure math --------------------------------------------------------------------

func test_view_left_follows_the_camera_order() -> String:
	# A 512-wide view whose unlimited left edge is 500, limits [680, 1320].
	var r: String = _T.assert_float_eq(BLEND.view_left(500.0, 680.0, 1320.0, 512.0), 680.0, 0.01, "left binds")
	if r != "":
		return r
	r = _T.assert_float_eq(BLEND.view_left(1000.0, 680.0, 1320.0, 512.0), 808.0, 0.01, "right binds")
	if r != "":
		return r
	return _T.assert_float_eq(BLEND.view_left(700.0, 680.0, 1320.0, 512.0), 700.0, 0.01, "free inside")


func test_blend_weight_is_eased_and_clamped() -> String:
	var r: String = _T.assert_float_eq(BLEND.weight(-1.0), 0.0, 0.0001, "clamped low")
	if r != "":
		return r
	r = _T.assert_float_eq(BLEND.weight(2.0), 1.0, 0.0001, "clamped high")
	if r != "":
		return r
	return _T.assert_true(BLEND.weight(0.1) < 0.1, "eases in")


func test_new_blend_replaces_one_in_flight() -> String:
	_make()
	BLEND.blend(_cam, -100, 100, 5.0)
	BLEND.blend(_cam, -200, 200, 5.0)
	var count := 0
	for c in _cam.get_children():
		if c is CameraLimitBlend and not c.is_queued_for_deletion():
			count += 1
	var r: String = _T.assert_eq(count, 1, "one blend per camera")
	if r != "":
		return r
	return _T.assert_eq(BLEND.target_limits(_cam), Vector2i(-200, 200), "newest target wins")


func test_finished_blend_lands_exactly_and_frees_itself() -> String:
	_make()
	var b: CameraLimitBlend = BLEND.blend(_cam, -321, 456, 0.1)
	for i in 4:  # each step is capped at MAX_STEP
		b.step(0.2)
	var r: String = _T.assert_eq(Vector2i(_cam.limit_left, _cam.limit_right), Vector2i(-321, 456), "exact")
	if r != "":
		return r
	return _T.assert_true(b.is_queued_for_deletion(), "frees itself")


## Mutation survivor: a hitch frame (a quarter second of delta) must not cover half
## the pan in one frame.
func test_a_hitch_frame_advances_the_blend_by_one_step_only() -> String:
	_make()
	_cam.limit_left = -5000
	_cam.limit_right = 5000
	var b: CameraLimitBlend = BLEND.blend(_cam, -100, 100, 0.55)
	b.step(0.5)
	# The view starts 256 left of the player (at x 0) and ends at -100: one capped
	# step is ~1% of that ease, a raw half-second would be ~98%.
	return _T.assert_true(_cam.limit_left <= -240, "one long frame moved the view to %d" % _cam.limit_left)
