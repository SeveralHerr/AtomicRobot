extends Node

## Runs one autoplay scenario end to end: set up, execute steps, check expectations,
## print a short summary, write the JSON report and quit with an exit code.
##   0 = every check passed · 1 = a check failed / timeout · 2 = scenario invalid
## Created by scripts/autoload/autoplay.gd; see skills/godot-autoplay-test/SKILL.md.

const Scenario := preload("res://tools/autoplay/scenario.gd")
const Brain := preload("res://tools/autoplay/brain.gd")
const World := preload("res://tools/autoplay/world.gd")
const Pad := preload("res://tools/autoplay/pad.gd")
const Recorder := preload("res://tools/autoplay/recorder.gd")
const Report := preload("res://tools/autoplay/report.gd")

const BOOT_SCENE := "res://scenes/startscreen.tscn"
const MENU_TAP_S := 1.0
const WALK_TIMEOUT_S := 20.0
## Steps that act on the player: with none in the scene they fail, never no-op.
const PLAYER_VERBS := ["walk_to", "lane", "teleport", "spawn", "hp"]
## Steps that still make sense with a dead player: they drive the GAME OVER card
## (death beat -> initials -> RESTART) or record it.
const AFTER_DEATH_VERBS := ["wait", "tap", "menu", "snap", "dump", "assert"]
const WALK_ARRIVE_PX := 12.0
## The bot beats the boss; that must not unlock Robot in the developer's real save.
const UNLOCKS := "user://autoplay_unlocks.cfg"
## ...nor put bot bests and initials on the player's real high-score table.
const SCORES := "user://autoplay_scores.cfg"

var sc: Dictionary = {}
var pad: Pad
var rec: Recorder
var world := World.new()
var brain_mem: Dictionary = {}
var brain_on := false
## `brain advance S X`: the brain treats X as the goal and the step ends there.
var brain_stop_x := INF
var asserts: Array = []
var fail_reason := ""
## `god on` outlives the Player instance: boss_room.tscn has its own Player.
var god := false
var _finished := false
## Last frame's MicroCutscene.playing, to log each cut scene's start and end.
var _was_watching := false
var _source := ""


func setup(source: String, out_dir: String) -> void:
	_source = source
	var res := Scenario.load_source(source)
	sc = res["data"]
	pad = Pad.new()
	add_child(pad)
	rec = Recorder.new()
	rec.run_name = sc["name"]
	rec.snap_every = sc["snap_every"]
	rec.out_dir = out_dir
	add_child(rec)
	if not res["ok"]:
		for e in res["errors"]:
			printerr("AUTOPLAY scenario error: ", e)
		_finish.call_deferred(2, "invalid scenario: " + "; ".join(res["errors"]))
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	seed(sc["seed"])
	# tools/autoplay.py always runs --fixed-fps 60: hitstop must not zero time there.
	Utils.fixed_clock = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(UNLOCKS))
	Globals.use_unlock_save(UNLOCKS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCORES))
	ScoreSystem.save_path = SCORES
	ScoreSystem.reload()
	Globals.selected_character = sc["character"]
	_run.call_deferred()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -99


func _physics_process(_delta: float) -> void:
	if _finished or rec == null:
		return
	if god:
		_with_player(func(p: Player) -> void: p.god_mode = true)
	var snap := world.snapshot(get_tree(), rec.t, 1.0 / Engine.physics_ticks_per_second)
	if _watching() != _was_watching:
		_was_watching = _watching()
		rec.watching = _was_watching
		rec.log_event("cutscene", {"playing": _was_watching})
	if brain_on and not _watching():
		if is_finite(brain_stop_x):
			snap["goal_x"] = brain_stop_x
		var intent := Brain.decide(snap, brain_mem)
		rec.note_why(intent["why"])
		pad.apply(intent)
	rec.sample(snap, get_tree())
	if rec.t > sc["timeout"]:
		_finish(1, "timeout after %.0fs (step still running)" % sc["timeout"])


func _run() -> void:
	if not sc["boot"]:
		Globals.debug_start_game(sc["character"], sc["scene"])
		await _await_player(10.0)
		if World.player(get_tree()) == null:
			_finish(1, "no player appeared in %s within 10s" % sc["scene"])
			return
		await _await_baseline(3.0)
	elif World.scene_path(get_tree()) != BOOT_SCENE:
		get_tree().change_scene_to_file.call_deferred(BOOT_SCENE)
	for step: Dictionary in sc["steps"]:
		if _finished:
			return
		# A dead player can't do anything the next steps ask: stop and report —
		# unless the step drives the end card, or a restart brought a live one back.
		if _player_dead() and not step["verb"] in AFTER_DEATH_VERBS:
			rec.log_event("steps_skipped", {"reason": "player died", "next": step["text"]})
			break
		while _watching() and not _finished:
			await get_tree().physics_frame
		rec.log_event("step", {"do": step["text"]})
		await _do(step)
	if not _finished:
		_finish(0, "")


## A cut scene has the camera. Watch it like a player would: any new press skips it,
## so the brain and walk_to hold their keys and wait.
func _watching() -> bool:
	return MicroCutscene.playing


func _player_dead() -> bool:
	if rec.deaths == 0:
		return false
	var p := World.player(get_tree())
	return p == null or p.is_dead


func _do(step: Dictionary) -> void:
	var a: Array = step["args"]
	if step["verb"] in PLAYER_VERBS and World.player(get_tree()) == null:
		rec.fail_step(step["text"], "no player in %s" % World.scene_path(get_tree()).get_file())
		return
	match step["verb"]:
		"wait": await _wait(float(a[0]))
		"hold":
			pad.press(a[0])
			await _wait(float(a[1]))
			pad.release(a[0])
		"tap":
			pad.tap(a[0])
			# Press + release + cooldown, so a following `tap` of the same key lands.
			await _wait_frames(Pad.TAP_FRAMES * 2 + 1)
		"press": pad.press(a[0])
		"release": pad.release(a[0])
		"walk_to": await _walk_to(step["text"], float(a[0]), float(a[1]) if a.size() > 1 else WALK_TIMEOUT_S)
		"lane": await _lane(step["text"], int(a[0]))
		"teleport": await _teleport(float(a[0]))
		"spawn": await _spawn(step["text"], a)
		"god":
			god = a[0] == "on"
			_with_player(func(p: Player) -> void: p.god_mode = god)
		"hp": _with_player(func(p: Player) -> void:
			p.health = int(a[0])
			rec.rebase_hp(p.health)
			p.player_health_updated.emit(p.health))
		"kill_all":
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Enemy and not e.is_dead:
					rec.ignore_kill(e)
					e.die()
		"sink":
			# Reproduces the door-arena report: maids keeping their lane but standing
			# DY px off its floor (lane 0 at road height), out of a straight shot's line.
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Enemy and not e.is_dead and not e.lane_locked:
					e.global_position.y += float(a[0])
			await _wait_frames(2)
		"brain": await _brain(a[0], float(a[1]) if a.size() > 1 else sc["timeout"],
				float(a[2]) if a.size() > 2 else INF)
		"menu": await _menu(step["text"], float(a[0]) if a.size() > 0 else 30.0)
		"snap": rec.snap(a[0] if a.size() > 0 else "t%04d" % int(rec.t))
		"dump": rec.dump(a[0] if a.size() > 0 else "dump")
		"assert": _check(step["check"])


func _brain(goal: String, seconds: float, stop_x: float = INF) -> void:
	brain_mem = Brain.new_mem(goal, sc["seed"])
	brain_stop_x = stop_x
	brain_on = true
	# Levels and the boss room both progress rightward.
	rec.set_progress_dir(1 if goal == "advance" else 0)
	var deaths := rec.deaths
	var end := rec.t + seconds
	while not _finished and rec.t < end:
		if brain_mem["done"] or rec.won or rec.deaths > deaths:
			break
		# Arrived with nothing left to fight on the way ("at goal" outranks only advance).
		if is_finite(stop_x) and rec.last_why == "at goal":
			break
		await get_tree().physics_frame
	brain_on = false
	brain_stop_x = INF
	pad.release_all()
	rec.set_progress_dir(0)
	# The brain's last reason must not outlive it: a stale "fight" would hide
	# every later walk_to stall from the stuck metric.
	rec.last_why = ""
	rec.log_event("brain_end", {"goal": goal, "done": brain_mem["done"], "won": rec.won})


## Taps ui_accept (Enter) through the title, character select and controls
## screens until a player is in a lane-enabled level.
func _menu(text: String, seconds: float) -> void:
	var end := rec.t + seconds
	var next_tap := rec.t + MENU_TAP_S
	while not _finished and rec.t < end:
		var p := World.player(get_tree())
		if p and not p.is_dead and Lanes.scene_has_lanes(World.scene_path(get_tree())):
			await _await_baseline(3.0)
			return
		if rec.t >= next_tap:
			next_tap = rec.t + MENU_TAP_S
			pad.tap(&"ui_accept")
		await get_tree().physics_frame
	rec.fail_step(text, "still on %s after %ss" % [World.scene_path(get_tree()).get_file(), seconds])


func _walk_to(text: String, x: float, seconds: float) -> void:
	var end := rec.t + seconds
	var p := World.player(get_tree())
	if p:
		rec.set_progress_dir(1 if x > p.global_position.x else -1)
	while not _finished and rec.t < end:
		p = World.player(get_tree())
		if p == null:
			break
		if _watching():
			end += 1.0 / Engine.physics_ticks_per_second
			await get_tree().physics_frame
			continue
		var dx := x - p.global_position.x
		if absf(dx) <= WALK_ARRIVE_PX:
			break
		pad.steer(1 if dx > 0 else -1)
		await get_tree().physics_frame
	pad.steer(0)
	rec.set_progress_dir(0)
	p = World.player(get_tree())
	if p and absf(x - p.global_position.x) > WALK_ARRIVE_PX:
		rec.fail_step(text, "timeout at x=%d lane=%d" % [roundi(p.global_position.x), p.current_lane])


func _lane(text: String, target: int) -> void:
	for i in 8:
		var p := World.player(get_tree())
		if p == null or p.current_lane == target:
			break
		pad.tap(&"ui_down" if target > p.current_lane else &"ui_up")
		await _wait(0.3)
	var q := World.player(get_tree())
	if q == null or q.current_lane != target:
		rec.fail_step(text, "still on lane %s (lanes only exist in main.tscn, on the street)" % (q.current_lane if q else "?"))


func _teleport(x: float) -> void:
	_with_player(func(p: Player) -> void:
		p.global_position.x = x
		p.velocity = Vector2.ZERO)
	await _wait_frames(2)


## spawn melee|ranged [dx=300] [lane=player's]
func _spawn(text: String, a: Array) -> void:
	var p := World.player(get_tree())
	if p == null:
		rec.fail_step(text, "no player to spawn beside")
		return
	var dx := float(a[1]) if a.size() > 1 else 300.0
	var lane := int(a[2]) if a.size() > 2 else p.current_lane
	EnemySpawner.spawn_enemy_at(get_tree().current_scene, p, p.global_position.x + dx, lane, a[0] == "melee")
	await _wait_frames(2)


func _check(check: Dictionary) -> void:
	var r := Scenario.evaluate(check, rec.metrics(get_tree()))
	asserts.append(r)
	rec.log_event("assert", {"check": r["text"], "pass": r["pass"], "actual": r["actual"]})


func _with_player(fn: Callable) -> void:
	var p := World.player(get_tree())
	if p:
		fn.call(p)


func _await_player(seconds: float) -> void:
	var end := rec.t + seconds
	while not _finished and rec.t < end and World.player(get_tree()) == null:
		await get_tree().physics_frame


## Lane steps need the walkway baseline, which the player captures on first landing.
func _await_baseline(seconds: float) -> void:
	var end := rec.t + seconds
	while not _finished and rec.t < end:
		var p := World.player(get_tree())
		if p and (p.lane_floor_y != INF or not Lanes.scene_has_lanes(World.scene_path(get_tree()))):
			break
		await get_tree().physics_frame
	await _wait_frames(5)


func _wait(seconds: float) -> void:
	await _wait_frames(maxi(1, roundi(seconds * Engine.physics_ticks_per_second)))


func _wait_frames(n: int) -> void:
	for i in n:
		if _finished:
			return
		await get_tree().physics_frame


func _finish(code: int, reason: String) -> void:
	if _finished:
		return
	_finished = true
	brain_on = false
	pad.release_all()
	if code == 0:
		for check: Dictionary in sc.get("expect", []):
			_check(check)
		if not rec.step_failures.is_empty():
			var f: Dictionary = rec.step_failures[0]
			code = 1
			reason = "step failed: %s: %s" % [f["step"], f["reason"]]
		for r: Dictionary in asserts:
			if code != 0:
				break
			if not r["pass"]:
				code = 1
				reason = "check failed: %s (actual %s)" % [r["text"], r["actual"]]
				break
	fail_reason = reason
	if code != 0 and rec.can_snap():
		rec.snap("fail")
	var report := Report.build(sc.get("name", "inline"), code, reason, rec, asserts, get_tree())
	var path := Report.write(report, rec.out_dir)
	print(Report.summary(report, path))
	# Let a pending screenshot land before the process goes away.
	if rec.can_snap():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	get_tree().quit(code)
