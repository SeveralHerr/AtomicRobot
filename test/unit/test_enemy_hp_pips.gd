extends RefCounted

# Per-hit progress on multi-hit enemies: the tiny bar over a maid's head.

var _T

const MAID_SCENE := preload("res://scenes/meter_maid.tscn")
const BOSS_SCENE := preload("res://scenes/final_boss.tscn")

var _nodes: Array[Node] = []
var _kills_before: int


func setup() -> void:
	_kills_before = Globals.meter_maids_killed


func teardown() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	for n in _nodes:
		if is_instance_valid(n):
			Globals.release_attack_slot(n)
			n.free()
	_nodes.clear()
	Globals.meter_maids_killed = _kills_before


func _spawn(scene: PackedScene) -> Enemy:
	var e: Enemy = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(e)
	_nodes.append(e)
	e.set_process(false)
	e.set_physics_process(false)
	e.attack_timer.stop()
	return e


func _pips(e: Enemy) -> EnemyHpPips:
	return e.get_node_or_null(NodePath(EnemyHpPips.NODE_NAME)) as EnemyHpPips


func test_untouched_maid_has_no_bar() -> String:
	return _T.assert_eq(_pips(_spawn(MAID_SCENE)), null, "full health shows nothing")


func test_a_blow_shows_the_remaining_fraction() -> String:
	var e := _spawn(MAID_SCENE)
	e.receive_hit(3)
	var bar := _pips(e)
	if bar == null:
		return "no bar after a blow"
	return _T.assert_float_eq(bar.fill, float(e.max_health - 3) / float(e.max_health), 0.001, "fill")


func test_chip_lags_behind_the_fill() -> String:
	var e := _spawn(MAID_SCENE)
	e.receive_hit(3)
	var bar := _pips(e)
	var r: String = _T.assert_float_eq(bar.chip, 1.0, 0.001, "chip still shows the HP just lost")
	if r != "":
		return r
	bar._process(EnemyHpPips.CHIP_DELAY + 1.0)
	bar._process(1.0)
	return _T.assert_float_eq(bar.chip, bar.fill, 0.001, "chip drains down to the fill")


func test_second_blow_reuses_the_bar() -> String:
	var e := _spawn(MAID_SCENE)
	e.receive_hit(3)
	e.receive_hit(3)
	var n := 0
	for c in e.get_children():
		if c is EnemyHpPips:
			n += 1
	return _T.assert_eq(n, 1, "one bar per enemy")


func test_boss_never_gets_pips() -> String:
	var b := _spawn(BOSS_SCENE) as FinalBoss
	b.fighting = true
	b.receive_hit(3)
	var r: String = _T.assert_eq(b.health, b.max_health - 3, "blow landed")
	if r != "":
		return r
	return _T.assert_eq(_pips(b), null, "the HUD bar already shows it")


func test_notches_mark_one_blow_of_the_current_fighter() -> String:
	var e := _spawn(MAID_SCENE)
	e.receive_hit(1)
	var want := float(Globals.get_current_character().get_starting_damage()) / float(e.max_health)
	return _T.assert_float_eq(_pips(e).notch, want, 0.001, "notch = one blow")


func test_bar_lingers_then_fades() -> String:
	var r: String = _T.assert_float_eq(EnemyHpPips.alpha_at(0.0, false), 1.0, 0.001, "fresh hit")
	if r != "":
		return r
	r = _T.assert_float_eq(EnemyHpPips.alpha_at(EnemyHpPips.LINGER, false), 1.0, 0.001, "still lingering")
	if r != "":
		return r
	return _T.assert_float_eq(EnemyHpPips.alpha_at(EnemyHpPips.LINGER + EnemyHpPips.FADE, false), 0.0, 0.001, "gone")


func test_kill_blinks_out_fast() -> String:
	var r: String = _T.assert_float_eq(EnemyHpPips.alpha_at(0.0, true), 1.0, 0.001, "kill frame shows")
	if r != "":
		return r
	return _T.assert_float_eq(EnemyHpPips.alpha_at(EnemyHpPips.DEATH_FADE, true), 0.0, 0.001, "gone after the blink")


func test_bar_ignores_the_maids_mirroring() -> String:
	var e := _spawn(MAID_SCENE)
	e.set_facing(-1)
	e.receive_hit(3)
	var bar := _pips(e)
	return _T.assert_true(bar.get_global_transform().x.x > 0.0, "bar is never drawn mirrored")


# --- Flinch: a blow holds off her next swing (multi-hit kills need it) -----------

func test_blow_holds_off_the_next_swing() -> String:
	var e := _spawn(MAID_SCENE)
	e.receive_hit(3)
	var r: String = _T.assert_false(e.attack_timer.is_stopped(), "cooldown running after a blow")
	if r != "":
		return r
	r = _T.assert_float_eq(e.attack_timer.time_left, Enemy.FLINCH_TIME, 0.01, "flinch length")
	if r != "":
		return r
	return _T.assert_float_eq(e.attack_timer.wait_time, e.attack_cooldown, 0.01, "normal cooldown kept")


func test_flinch_never_shortens_a_longer_cooldown() -> String:
	var e := _spawn(MAID_SCENE)
	e.attack_timer.start(3.0)
	e.receive_hit(3)
	return _T.assert_gt(e.attack_timer.time_left, 2.5, "a long cooldown is not cut short")


func test_boss_does_not_flinch() -> String:
	var b := _spawn(BOSS_SCENE) as FinalBoss
	b.fighting = true
	b.receive_hit(3)
	return _T.assert_true(b.attack_timer.is_stopped(), "the boss keeps his own cadence")


## Two quick blows: the chip still shows everything lost since it last drained.
func test_quick_second_blow_keeps_the_whole_chip() -> String:
	var e := _spawn(MAID_SCENE)
	e.receive_hit(3)
	e.receive_hit(3)
	var bar := _pips(e)
	return _T.assert_float_eq(bar.chip, 1.0, 0.001, "chip spans both chunks")
