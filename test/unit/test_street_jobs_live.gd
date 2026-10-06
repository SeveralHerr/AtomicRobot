extends RefCounted

## Street side jobs on a real player and real maids: start, win, miss, death, watchdog,
## rewards — with the one guarantee every job shares: it ends exactly once and never
## soft-locks. Pure rules: test_street_objectives.gd.

var _T
const SO = preload("res://scripts/objectives/street_objective.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _stage: Node2D
var _p: Player
var _old_scene: Node
var _job: StreetObjective
var _ended: Array = []
var _reports: Array = []
## Global scripted-fight count, isolated per test: an earlier suite leaves an event
## pushed, and a job never starts while one is live.
var _saved_events: int = 0


# --- Lifecycle (real player, real maids) ------------------------------------------------

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make(job: StreetObjective) -> void:
	_ended = []
	_reports = []
	_saved_events = Globals._active_events
	Globals._active_events = 0
	_stage = Node2D.new()
	_tree().root.add_child(_stage)
	_old_scene = _tree().current_scene
	_tree().current_scene = _stage
	_p = PLAYER_SCENE.instantiate()
	_stage.add_child(_p)
	_p.set_process(false)
	_p.set_physics_process(false)
	_p.lane_floor_y = 0.0
	_p.global_position = Vector2(5000, -20)
	_job = job
	_stage.add_child(_job)
	_job.finished.connect(func(ok: bool) -> void: _ended.append(ok))
	Globals.objective_finished.connect(_on_report)


func _on_report(id: String, ok: bool) -> void:
	_reports.append([id, ok])


func teardown() -> void:
	if Globals.objective_finished.is_connected(_on_report):
		Globals.objective_finished.disconnect(_on_report)
	if _stage == null:
		return
	Globals._active_events = _saved_events
	_tree().current_scene = _old_scene
	for e in _tree().get_nodes_in_group("enemies"):
		Globals.release_attack_slot(e)
	await _tree().process_frame
	_stage.free()
	_stage = null


func _until(cond: Callable, seconds: float = 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func _chase() -> SnatchChase:
	var c := SnatchChase.new()
	c.trigger_x = 5000.0
	c.keys_x = 4880.0
	c.spawn_dist = 60.0
	return c


func test_job_chase_starts_on_the_mark_and_the_thief_grabs_the_keys() -> String:
	var c := _chase()
	_make(c)
	_p.global_position.x = 4990.0
	await _tree().process_frame
	await _tree().process_frame
	var r: String = _T.assert_eq(c.phase, StreetObjective.Phase.WAITING, "short of the mark")
	if r != "":
		return r
	r = _T.assert_true(is_instance_valid(c.keys), "keys lie on the walkway before the job")
	if r != "":
		return r
	_p.global_position.x = 5010.0
	var ok: bool = await _until(func(): return c.phase == StreetObjective.Phase.RUNNING)
	if not ok:
		return "job never started past the mark (event=%s cutscene=%s floor=%s)" % [
			Globals.event_active(), MicroCutscene.playing, _p.lane_floor_y]
	ok = await _until(func(): return c.grabbed)
	if not ok:
		return "thief never grabbed the keys"
	r = _T.assert_true(c.keys.get_parent() == c.thief, "she carries them")
	if r != "":
		return r
	return _T.assert_true(c.thief.enemy_state_machine.current_state is ThiefState, "she is the thief")


func test_job_chase_one_blow_wins_once_and_pays() -> String:
	var c := _chase()
	_make(c)
	await _tree().process_frame  # ScoreSystem stops scoring on the stage swap first
	ScoreSystem.running = true
	var before := ScoreSystem.score
	c.start(_p)
	await _until(func(): return c.grabbed)
	c.thief.receive_hit(1)
	var ok: bool = await _until(func(): return not _ended.is_empty())
	ScoreSystem.running = false
	if not ok:
		return "blow never ended the chase"
	var r: String = _T.assert_eq(_ended, [true], "won exactly once")
	if r != "":
		return r
	r = _T.assert_eq(_reports, [["snatch_chase", true]], "reported once")
	if r != "":
		return r
	r = _T.assert_eq(ScoreSystem.score - before, c.reward_points, "paid the reward")
	if r != "":
		return r
	return _T.assert_true(c.thief.enemy_state_machine.current_state is ChasePlayerState, "she turns on the player")


func test_job_chase_thief_escaping_is_a_miss_and_she_leaves() -> String:
	var c := _chase()
	_make(c)
	c.start(_p)
	await _until(func(): return c.grabbed)
	c.thief.global_position.x = c.keys_x - c.escape_dist - 5.0
	var ok: bool = await _until(func(): return not _ended.is_empty())
	if not ok:
		return "escape never ended the chase"
	var r: String = _T.assert_eq(_ended, [false], "missed once")
	if r != "":
		return r
	return _T.assert_true(await _until(func(): return not is_instance_valid(c.thief)), "she fades off the street")


func test_job_chase_clock_waits_for_the_grab() -> String:
	var c := _chase()
	c.spawn_dist = 400.0
	_make(c)
	c.start(_p)
	await _tree().process_frame
	await _tree().process_frame
	return _T.assert_eq(c.time_left, c.time_limit, "no time lost before she has the keys")


func test_job_chase_runs_out_of_time() -> String:
	var c := _chase()
	_make(c)
	c.time_limit = 0.3
	c.start(_p)
	var ok: bool = await _until(func(): return not _ended.is_empty())
	return _T.assert_true(ok and _ended == [false], "clock ran out: a miss (%s)" % [_ended])


func test_job_death_mid_job_ends_it_quietly_once() -> String:
	var c := _chase()
	_make(c)
	c.start(_p)
	await _tree().process_frame
	c._on_player_death()
	c._on_player_death()
	await _tree().process_frame
	var r: String = _T.assert_eq(_ended, [false], "ended once, as a miss")
	if r != "":
		return r
	return _T.assert_false(is_instance_valid(c.hud), "card gone with the death beat")


func test_job_watchdog_ends_a_job_whose_rules_never_close() -> String:
	var c := _chase()
	c.spawn_dist = 3000.0  # she never reaches the keys: the clock never starts
	_make(c)
	c.start(_p)
	c._age = c.time_limit + SO.WATCHDOG_SLACK
	var ok: bool = await _until(func(): return not _ended.is_empty())
	return _T.assert_true(ok, "watchdog closed the job")


func _defense() -> MeterDefense:
	var d := MeterDefense.new()
	d.trigger_x = 5000.0
	d.car_xs = [5100.0, 5250.0]
	d.maid_count = 2
	d.maid_stagger = 0.0
	d.spawn_past = 60.0
	d.ticket_seconds = 0.2
	return d


func test_job_defense_tickets_every_car_is_a_miss() -> String:
	var d := _defense()
	_make(d)
	d._park(0.0)
	d.start(_p)
	var ok: bool = await _until(func(): return not _ended.is_empty(), 6.0)
	if not ok:
		return "maids never ticketed the cars (tickets=%d)" % d.tickets
	var r: String = _T.assert_eq(_ended, [false], "all ticketed: a miss")
	if r != "":
		return r
	r = _T.assert_eq(d.tickets, 2, "both cars ticketed")
	if r != "":
		return r
	return _T.assert_true(d.cars.all(func(car): return car.ticketed), "slips on both cars")


func test_job_defense_squad_down_with_a_clean_car_wins() -> String:
	var d := _defense()
	d.ticket_seconds = 30.0
	_make(d)
	d._park(0.0)
	await _tree().process_frame  # ScoreSystem stops scoring on the stage swap first
	ScoreSystem.running = true
	var before := ScoreSystem.score
	d.start(_p)
	await _until(func(): return d.maids.size() == 2)
	await _tree().process_frame
	await _tree().process_frame
	for m in d.maids:
		m.receive_hit(99)
	var ok: bool = await _until(func(): return not _ended.is_empty())
	ScoreSystem.running = false
	if not ok:
		return "squad down never ended the job"
	var r: String = _T.assert_eq(_ended, [true], "won")
	if r != "":
		return r
	r = _T.assert_eq(d.reward_points, 2 * d.points_per_car, "both cars pay")
	if r != "":
		return r
	# The KOs score their own kill points on top.
	return _T.assert_gte(ScoreSystem.score - before, d.reward_points, "reward banked")


func test_job_defense_hit_maid_fights_then_goes_back_to_the_cars() -> String:
	var d := _defense()
	d.maid_count = 1
	d.ticket_seconds = 30.0
	d.grudge_seconds = 0.2
	_make(d)
	d._park(0.0)
	d.start(_p)
	await _until(func(): return d.maids.size() == 1 and d.maids[0].enemy_state_machine.current_state is TicketState)
	var m: Enemy = d.maids[0]
	m.receive_hit(1)
	await _tree().process_frame
	await _tree().process_frame
	var r: String = _T.assert_true(m.enemy_state_machine.current_state is ChasePlayerState, "a blow pulls her off the car")
	if r != "":
		return r
	var ok: bool = await _until(func(): return m.enemy_state_machine.current_state is TicketState)
	return _T.assert_true(ok, "left alone, she goes back to writing")


## Knocking a writer off her car tears the ticket up (scraps), so the blow pays off.
func test_job_defense_blow_tears_up_the_ticket_being_written() -> String:
	var d := _defense()
	d.maid_count = 1
	d.ticket_seconds = 30.0
	_make(d)
	d._park(0.0)
	d.start(_p)
	var ok: bool = await _until(func(): return d.cars.any(func(c): return c.progress > 0.0), 6.0)
	if not ok:
		return "she never started writing"
	var car: ParkedCar = d.cars.filter(func(c): return c.progress > 0.0)[0]
	d.maids[0].receive_hit(1)
	await _tree().process_frame
	await _tree().process_frame
	return _T.assert_true(car.get_node_or_null("TornTicket") != null, "scraps burst off the slip")


## The card's pips follow the cars one to one: a ticket on the far car lit the FIRST
## pip, and a ticket being written off screen showed nowhere on the card.
func test_job_defense_pips_track_each_car() -> String:
	var d := _defense()
	d.maid_count = 0
	_make(d)
	d._park(0.0)
	d.start(_p)
	var r: String = _T.assert_eq(Array(d.pip_values()), [0.0, 0.0], "clean")
	if r != "":
		return r
	r = _T.assert_gt(d.cars[0]._shine, 0.0, "the cars glint as the job opens")
	if r != "":
		return r
	d.cars[0].progress = 0.5
	d.on_ticket(d.cars[1])
	r = _T.assert_eq(Array(d.pip_values()), [0.5, 1.0], "writing on car 1, car 2 ticketed")
	if r != "":
		return r
	return _T.assert_eq(Array(d.hud.pips), [0.5, 1.0], "the card shows it")


func test_job_defense_one_maid_per_car() -> String:
	var d := _defense()
	_make(d)
	d._park(0.0)
	var scene: PackedScene = load("res://scenes/meter_maid_melee.tscn")
	var a: Enemy = scene.instantiate()
	var b: Enemy = scene.instantiate()
	var c: Enemy = scene.instantiate()
	for m in [a, b, c]:
		m.process_mode = Node.PROCESS_MODE_DISABLED
		_stage.add_child(m)
		m.global_position = Vector2(5100, 0)
	var r: String = _T.assert_true(d.claim_car(a) == d.cars[0], "nearest car")
	if r == "":
		r = _T.assert_true(d.claim_car(b) == d.cars[1], "the other car, not a shared one")
	if r == "":
		r = _T.assert_true(d.claim_car(c) == null, "no free car left: she fights instead")
	return r


func test_job_win_knocks_a_heart_loose_that_lands_before_it_heals() -> String:
	var c := _chase()
	_make(c)
	var before := _tree().get_nodes_in_group("atomic_hearts").size()
	c.start(_p)
	await _until(func(): return c.grabbed)
	c.thief.receive_hit(1)
	await _until(func(): return not _ended.is_empty())
	var hearts := _tree().get_nodes_in_group("atomic_hearts")
	var r: String = _T.assert_eq(hearts.size(), before + 1, "one heart for the win")
	if r != "":
		return r
	var heart: Node = hearts[hearts.size() - 1]
	await _tree().physics_frame
	r = _T.assert_false(heart.get_node("Area2D").monitoring, "not collectable mid-air")
	if r != "":
		return r
	var landed: bool = await _until(func(): return heart.get_node("Area2D").monitoring)
	return _T.assert_true(landed, "collectable once it lands")


## A running job holds ambient traffic like a door fight: its squad walks the road
## lane the parked cars push traffic into.
func test_job_running_flag_spans_the_job_and_clears_on_end_and_death() -> String:
	var d := _defense()
	d.maid_count = 0
	_make(d)
	d._park(0.0)
	var r: String = _T.assert_false(StreetObjective.any_running(_tree()), "waiting")
	if r != "":
		return r
	d.start(_p)
	r = _T.assert_true(AmbientTraffic.scripted_fight(_tree()), "traffic holds for the job")
	if r != "":
		return r
	d.finish(true)
	r = _T.assert_false(StreetObjective.any_running(_tree()), "finished")
	if r != "":
		return r
	var c := _chase()
	_make(c)
	c.start(_p)
	c._on_player_death()
	return _T.assert_false(StreetObjective.any_running(_tree()), "a death ends it too")


func test_job_finish_pays_and_reports_only_once() -> String:
	var c := _chase()
	_make(c)
	c.start(_p)
	c.finish(true)
	c.finish(false)
	await _tree().process_frame
	var r: String = _T.assert_eq(_ended, [true], "first outcome stands")
	if r != "":
		return r
	return _T.assert_eq(_reports.size(), 1, "reported once")


## The distance purge (Enemy.is_too_far) would free a fleeing thief or a ticketing
## maid the player walked away from — and the job would read her vanishing as a win.
func test_job_actors_are_never_purged_for_distance() -> String:
	var c := _chase()
	_make(c)
	c.start(_p)
	var ok: bool = await _until(func(): return is_instance_valid(c.thief) and c.thief.is_inside_tree())
	if not ok:
		return "no thief"
	return _T.assert_true(c.thief.persist, "thief persists while she runs")
