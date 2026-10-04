extends RefCounted

# The Transition autoload (scripts/autoload/transition.gd): the one fader every
# menu/level change goes through. Driven through fade_through() with a stub swap, so a
# test never replaces the runner's scene.

var _T

## Every script allowed to call SceneTree.change_scene_* itself. Everything else must
## go through Transition. Derived both ways: an entry that no longer calls it fails too.
const DIRECT_CHANGERS := {
	"res://scripts/autoload/transition.gd": "the fader itself",
	"res://scripts/autoload/globals.gd": "debug_start_game: dev/test entry, instant",
	"res://tools/autoplay/runner.gd": "bot boot, debug only",
	"res://test/scenes/enemy_sandbox.gd": "sandbox reload, test only",
}
const SCAN_DIRS := ["res://scripts", "res://tools/autoplay", "res://test/scenes"]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _t() -> Node:
	return _tree().root.get_node("Transition")


func teardown() -> void:
	# Never leave a failed test's fade holding the tree paused for the next one.
	while _t().busy:
		await _tree().process_frame
	_tree().paused = false
	Engine.time_scale = 1.0


func test_layer_sits_under_the_crt_and_over_every_scene() -> String:
	var crt_layer: int = _tree().root.get_node("CRTOverlay").OVERLAY_LAYER
	var r: String = _T.assert_gt(crt_layer, _t().layer, "fade is filmed through the CRT")
	if r != "":
		return r
	var pause_layer: int = _tree().root.get_node("PauseMenu").layer
	return _T.assert_gte(_t().layer, pause_layer, "nothing shows through the black")


func test_swaps_only_once_fully_black_and_paused() -> String:
	var seen := {}
	var swap := func() -> Error:
		seen["alpha"] = _t().get_node("Fade").modulate.a
		seen["paused"] = _tree().paused
		return OK
	var ok: bool = await _t().fade_through(swap)
	var r: String = _T.assert_true(ok, "fade_through reports success")
	if r != "":
		return r
	r = _T.assert_float_eq(seen.get("alpha", -1.0), 1.0, 0.001, "screen black at the swap")
	if r != "":
		return r
	return _T.assert_true(seen.get("paused", false), "tree paused at the swap (no input mid-fade)")


func test_ends_clear_unpaused_and_idle() -> String:
	await _t().fade_through(func() -> Error: return OK)
	var fade: ColorRect = _t().get_node("Fade")
	var r: String = _T.assert_false(_t().busy, "idle after")
	if r != "":
		return r
	r = _T.assert_false(_tree().paused, "tree unpaused after the fade-in")
	if r != "":
		return r
	r = _T.assert_false(fade.visible, "fader hidden after")
	if r != "":
		return r
	return _T.assert_eq(fade.mouse_filter, Control.MOUSE_FILTER_IGNORE, "fader stops eating clicks")


func test_blocks_input_while_fading() -> String:
	var fade: ColorRect = _t().get_node("Fade")
	var state := {}
	var swap := func() -> Error:
		state["filter"] = fade.mouse_filter
		return OK
	await _t().fade_through(swap)
	return _T.assert_eq(state.get("filter", -1), Control.MOUSE_FILTER_STOP, "fader eats clicks mid-fade")


func test_second_request_while_fading_is_dropped() -> String:
	var swaps := [0]
	var swap := func() -> Error:
		swaps[0] += 1
		return OK
	_t().fade_through(swap)  # not awaited: still fading out
	await _tree().process_frame
	var second: bool = await _t().fade_through(swap)
	var r: String = _T.assert_false(second, "second request refused")
	if r != "":
		return r
	while _t().busy:
		await _tree().process_frame
	return _T.assert_eq(swaps[0], 1, "scene swapped once")


func test_fades_take_their_time() -> String:
	var start := Time.get_ticks_msec()
	var swapped_at := [0]
	await _t().fade_through(func() -> Error:
		swapped_at[0] = Time.get_ticks_msec()
		return OK)
	var out_ms: int = swapped_at[0] - start
	var in_ms: int = Time.get_ticks_msec() - swapped_at[0]
	var r: String = _T.assert_gte(out_ms, int(_t().OUT_SECONDS * 1000) - 20, "fade-out lasts OUT_SECONDS")
	if r != "":
		return r
	return _T.assert_gte(in_ms, int(_t().IN_SECONDS * 1000) - 20, "fade-in lasts IN_SECONDS")


func test_restores_time_scale_on_change() -> String:
	Engine.time_scale = 0.35
	var at_swap := [0.0]
	await _t().fade_through(func() -> Error:
		at_swap[0] = Engine.time_scale
		return OK)
	return _T.assert_float_eq(at_swap[0], 1.0, 0.001, "slow-mo never leaks into the next scene")


func test_failed_swap_recovers() -> String:
	var ok: bool = await _t().fade_through(func() -> Error: return ERR_CANT_OPEN)
	var r: String = _T.assert_false(ok, "failure reported")
	if r != "":
		return r
	r = _T.assert_false(_t().busy, "not stuck busy")
	if r != "":
		return r
	return _T.assert_false(_tree().paused, "not stuck paused")


func test_sting_plays_on_the_autoload() -> String:
	var sting: AudioStream = load("res://sounds/711657__discofield__stone-crash.wav")
	var player: AudioStreamPlayer = null
	for c in _t().get_children():
		if c is AudioStreamPlayer:
			player = c
	var heard := [null]
	await _t().fade_through(func() -> Error:
		heard[0] = player.stream if player.playing else null
		return OK, sting)
	return _T.assert_eq(heard[0], sting, "sting playing through the fade")


func test_pause_key_cannot_unpause_a_fade() -> String:
	var pm := _tree().root.get_node("PauseMenu")
	var state := {}
	await _t().fade_through(func() -> Error:
		Input.action_press("pause")
		pm._process(0.0)
		Input.action_release("pause")
		state["paused"] = _tree().paused
		state["menu"] = pm.visible
		return OK)
	pm.visible = false
	var r: String = _T.assert_true(state.get("paused", false), "fade keeps the tree paused")
	if r != "":
		return r
	return _T.assert_false(state.get("menu", true), "pause menu stays shut mid-fade")


## Every player-facing scene change goes through the fader (derived from the source).
func test_scene_changes_go_through_transition() -> String:
	var callers := {}
	for dir in SCAN_DIRS:
		_scan(dir, callers)
	for path in callers:
		if not DIRECT_CHANGERS.has(path):
			return "%s changes scene directly; use Transition.change_scene_to_*" % path
	for path in DIRECT_CHANGERS:
		if not callers.has(path):
			return "%s is allow-listed but no longer changes scene; drop it" % path
	return ""


func _scan(dir: String, out: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var path := dir.path_join(f)
			var src := FileAccess.get_file_as_string(path)
			if src.contains("get_tree().change_scene_to") or src.contains("reload_current_scene") \
					or src.contains("tree.change_scene_to"):
				out[path] = true
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), out)
