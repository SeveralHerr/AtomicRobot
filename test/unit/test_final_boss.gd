extends RefCounted

## FinalBoss's fight rules: no damage before the intro hands over, a phase change
## staggers him (invulnerable), the killing blow starts the finale exactly once.
## Plus the pure pieces of his attacks: the charge's contact box and the fan's
## one-hit link.

var _T

const FINAL_BOSS := preload("res://scenes/final_boss.tscn")
const BRIEFCASE := preload("res://scenes/briefcase_bullet2.tscn")

var _boss: FinalBoss
var _phases: Array[int] = []
var _defeats: int = 0


func setup() -> void:
	_boss = FINAL_BOSS.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(_boss)
	_phases.clear()
	_defeats = 0
	_boss.phase_changed.connect(func(p: int) -> void: _phases.append(p))
	_boss.defeated.connect(func() -> void: _defeats += 1)


func teardown() -> void:
	_boss.free()
	_boss = null
	# Hits start a hit-stop / slow-mo whose restore timer never fires in a sync test.
	BossJuice.reset_time()


func test_starts_at_full_health_in_phase_zero() -> String:
	var r: String = _T.assert_eq(_boss.health, BossRules.MAX_HEALTH, "full health")
	if r == "":
		r = _T.assert_eq(_boss.phase, 0, "phase 0")
	return r


func test_hits_before_the_fight_do_nothing() -> String:
	_boss.receive_hit(5)
	return _T.assert_eq(_boss.health, BossRules.MAX_HEALTH, "intro boss is untouchable")


func test_hit_during_fight_lands() -> String:
	_boss.fighting = true
	_boss.receive_hit(2)
	return _T.assert_eq(_boss.health, BossRules.MAX_HEALTH - 2, "damage applied")


func test_crossing_a_threshold_changes_phase_and_staggers() -> String:
	_boss.fighting = true
	_boss.health = int(BossRules.MAX_HEALTH * BossRules.PHASE_STARTS[1]) + 1
	_boss.receive_hit(1)
	var r: String = _T.assert_eq(_phases, [1] as Array[int], "phase_changed(1) once")
	if r == "":
		r = _T.assert_true(_boss.staggered, "staggered after the phase change")
	return r


func test_staggered_boss_takes_no_damage() -> String:
	_boss.fighting = true
	_boss.staggered = true
	_boss.receive_hit(3)
	return _T.assert_eq(_boss.health, BossRules.MAX_HEALTH, "stagger is invulnerable")


func test_killing_blow_starts_finale_once() -> String:
	_boss.fighting = true
	_boss.health = 1
	_boss.receive_hit(1)
	_boss.receive_hit(1)
	var r: String = _T.assert_eq(_defeats, 1, "defeated emitted once")
	if r == "":
		r = _T.assert_false(_boss.fighting, "stops fighting on the killing blow")
	return r


func test_phase_skip_on_big_hit_lands_in_right_phase() -> String:
	_boss.fighting = true
	_boss.receive_hit(BossRules.MAX_HEALTH - 2)  # straight past both thresholds
	return _T.assert_eq(_boss.phase, 2, "a huge hit jumps to the last phase")


## Round-1 video: the first briefcase left his hand ~0.5 s after FIGHT!, while the
## white FIGHT! flash still covered his wind-up — an unreadable opening hit.
func test_first_throw_waits_out_the_opening_grace() -> String:
	_boss.begin_fight()
	var st = _boss.enemy_state_machine.current_state
	var r: String = _T.assert_true(st is BossAttackPlayerState, "fight opens in the throw state")
	if r == "":
		r = _T.assert_true(st.attack_finished, "no swing on the first frame")
	if r == "":
		r = _T.assert_true(_boss.animated_sprite_2d.animation != "attack", "no wind-up under the flash")
	if r == "":
		r = _T.assert_true(is_equal_approx(st.re_arm_delay - st._hold, BossRules.OPENING_GRACE),
			"first swing re-arms after OPENING_GRACE (%.2f left)" % (st.re_arm_delay - st._hold))
	if r == "":
		r = _T.assert_true(BossRules.OPENING_GRACE >= 0.8, "a beat to read FIGHT! and move")
	return r


func test_dash_contact_box() -> String:
	var cases := [
		[0.0, 0.0, 10.0, 0.0, true, "standing beside him"],
		[0.0, 0.0, -20.0, 5.0, true, "crouched/low beside him"],
		[0.0, 0.0, 60.0, 0.0, false, "out of reach"],
		[0.0, 0.0, 10.0, -60.0, false, "jumped over him"],
	]
	for c in cases:
		var r: String = _T.assert_eq(BossDashState.contact(c[0], c[1], c[2], c[3]), c[4], c[5])
		if r != "":
			return r
	return ""


func test_fan_disarms_siblings_after_a_hit() -> String:
	var fan := _fan(3)
	fan[0].has_hit_player = true
	fan[0].free()
	var r: String = _T.assert_true(fan[1].has_hit_player and fan[2].has_hit_player, "siblings disarmed")
	_free(fan)
	return r


func test_fan_miss_leaves_siblings_armed() -> String:
	var fan := _fan(3)
	fan[0].free()  # left the tree without hitting (timed out / fell away)
	var r: String = _T.assert_false(fan[1].has_hit_player or fan[2].has_hit_player, "still armed")
	_free(fan)
	return r


func _fan(n: int) -> Array[Bullet]:
	var fan: Array[Bullet] = []
	for i in n:
		var b: Bullet = BRIEFCASE.instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(b)
		fan.append(b)
	BossAttackPlayerState.link_fan(fan)
	return fan


func _free(fan: Array[Bullet]) -> void:
	for b in fan:
		if is_instance_valid(b):
			b.free()
