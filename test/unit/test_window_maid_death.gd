extends RefCounted

# A window maid's scene carries the window itself (Background / TopWindow /
# BottomWindow sprites). Death used to blink `self.modulate` and queue_free the whole
# node, so the smashed window blinked and vanished with her. Only the maid should go.
#
# Engine.time_scale speeds the ~3s blink up; the tween reads scaled delta.

var _T

const WINDOW_SCENE := preload("res://scenes/meter_maid_window.tscn")
const MAID_SCENE := preload("res://scenes/meter_maid.tscn")
const WINDOW_PARTS := ["Background", "TopWindow", "BottomWindow"]

var _nodes: Array[Node] = []


func setup() -> void:
	Engine.time_scale = 20.0


func teardown() -> void:
	Engine.time_scale = 1.0
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _spawn(scene: PackedScene) -> Enemy:
	var e: Enemy = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(e)
	e.set_physics_process(false)
	# The window maid hides herself deferred on _ready; show her once that has run,
	# as _activate() would in game.
	await tree.process_frame
	e.show()
	_nodes.append(e)
	return e


func _min_window_alpha_during_blink(maid: Enemy) -> float:
	var lowest := 1.0
	var done := [false]
	var blink := func() -> void:
		await maid._play_death_blink()
		done[0] = true
	blink.call()
	var tree := Engine.get_main_loop() as SceneTree
	while not done[0]:
		await tree.process_frame
		lowest = minf(lowest, maid.modulate.a)
		for part in WINDOW_PARTS:
			lowest = minf(lowest, (maid.get_node(part) as CanvasItem).modulate.a)
	return lowest


func test_window_frame_never_blinks_during_death() -> String:
	var maid := await _spawn(WINDOW_SCENE)
	return _T.assert_float_eq(await _min_window_alpha_during_blink(maid), 1.0, 0.001,
		"window frame alpha through the whole blink")


func test_maid_sprite_does_blink() -> String:
	var maid := await _spawn(WINDOW_SCENE)
	var lowest := [1.0]
	var done := [false]
	var tree := Engine.get_main_loop() as SceneTree
	var watch := func() -> void:
		while not done[0]:
			lowest[0] = minf(lowest[0], maid.animated_sprite_2d.modulate.a)
			await tree.process_frame
	watch.call()
	await maid._play_death_blink()
	done[0] = true
	return _T.assert_float_eq(lowest[0], 0.0, 0.05, "maid sprite fades out while blinking")


func test_after_blink_window_stays_and_maid_is_gone() -> String:
	var maid := await _spawn(WINDOW_SCENE)
	await maid._play_death_blink()
	maid._on_death_blink_finished()
	await (Engine.get_main_loop() as SceneTree).process_frame
	var r: String = _T.assert_true(is_instance_valid(maid) and not maid.is_queued_for_deletion(),
		"window node survives the death")
	if r != "":
		return r
	r = _T.assert_false(maid.animated_sprite_2d.visible, "maid sprite hidden")
	if r != "":
		return r
	for part in WINDOW_PARTS:
		var c := maid.get_node(part) as CanvasItem
		r = _T.assert_true(c.is_visible_in_tree() and c.modulate.a == 1.0, "%s still drawn" % part)
		if r != "":
			return r
	return ""


## Street maids keep the old behaviour: the whole body blinks and is freed.
func test_street_maid_still_blinks_whole_body_and_frees() -> String:
	var maid := await _spawn(MAID_SCENE)
	var r: String = _T.assert_eq(maid._death_blink_target(), maid, "street maid blinks herself")
	if r != "":
		return r
	await maid._play_death_blink()
	maid._on_death_blink_finished()
	return _T.assert_true(maid.is_queued_for_deletion(), "street maid corpse is freed")
