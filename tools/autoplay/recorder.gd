extends Node

## Watches a run and turns it into metrics, a short event log, screenshots and the
## final report. Samples the world snapshot every physics frame; never drives input.

const MAX_EVENTS := 2000
const MAX_AUTO_SNAPS := 12
## A stuck episode is logged once the player has made no forward progress for this
## long (fights stand still for a few seconds; that is not stuck).
const STUCK_LOG_S := 5.0
## Movement smaller than this is not progress.
const PROGRESS_PX := 6.0


## Captures engine/script errors raised anywhere during the run. Logger callbacks
## can arrive from other threads, hence the mutex.
class ErrorLog extends Logger:
	var mutex := Mutex.new()
	var script_errors := 0
	var engine_errors := 0
	var warnings := 0
	var entries := {}

	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtrace: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		if error_type == ERROR_TYPE_WARNING:
			warnings += 1
		else:
			# push_error() arrives as ERROR_TYPE_ERROR but is reported at a .gd
			# site; engine errors (even ones a script call triggered) are at .cpp.
			if error_type == ERROR_TYPE_SCRIPT or file.ends_with(".gd"):
				script_errors += 1
			else:
				engine_errors += 1
			var key := "%s:%d %s" % [file.get_file(), line, rationale if rationale != "" else code]
			entries[key] = entries.get(key, 0) + 1
		mutex.unlock()


var out_dir: String = ""
var run_name: String = "run"
var snap_every: float = 0.0
var errors := ErrorLog.new()
var events: Array = []
var dropped_events := 0
var scenes: PackedStringArray = []
var snaps: PackedStringArray = []
var stuck_spots: Array = []

var t: float = 0.0
var frames: int = 0
var kills := 0
var damage_taken := 0
var hits_taken := 0
var heals := 0
var deaths := 0
var won := false
var max_stuck_s := 0.0
var last_why := ""

var step_failures: Array = []
## Direction the current step is trying to move the player (+1 right, -1 left, 0 =
## not a movement step). Set by the runner for `brain advance` and `walk_to`.
var progress_dir: int = 0

var _player_id: int = 0
var _last_hp: int = 0
var _dead_ids := {}
var _scene := ""
var _stuck_logged := false
var _best_progress := -INF
var _stall_s := 0.0
var _next_auto_snap := 0.0
var _auto_snaps := 0
var _last_snap: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.add_logger(errors)
	Globals.player_death.connect(func() -> void:
		deaths += 1
		log_event("death", {"x": _last_snap.get("player", {}).get("x", 0.0)}))
	Globals.boss_death.connect(func() -> void:
		won = true
		log_event("win", {}))


func _exit_tree() -> void:
	OS.remove_logger(errors)


func can_snap() -> bool:
	return DisplayServer.get_name() != "headless"


func log_event(kind: String, data: Dictionary) -> void:
	if events.size() >= MAX_EVENTS:
		dropped_events += 1
		return
	var e := {"t": snappedf(t, 0.01), "ev": kind}
	e.merge(data)
	events.append(e)


## Per physics frame.
func sample(snap: Dictionary, tree: SceneTree) -> void:
	_last_snap = snap
	frames += 1
	t = float(frames) / Engine.physics_ticks_per_second
	_track_scene(tree)
	_track_player(tree)
	_track_kills(tree)
	_track_stuck(snap)
	if snap_every > 0.0 and t >= _next_auto_snap:
		_next_auto_snap = t + snap_every
		# Frame-numbered: whole-second labels overwrote every sub-second snap.
		snap("f%06d" % frames)


func _track_scene(tree: SceneTree) -> void:
	# current_scene is null for a frame or two while a scene swaps: not a scene.
	var path := tree.current_scene.scene_file_path if tree.current_scene else ""
	if path == "" or path == _scene:
		return
	_scene = path
	_best_progress = -INF
	scenes.append(path.get_file().get_basename())
	log_event("scene", {"scene": path.get_file().get_basename()})


func _track_player(tree: SceneTree) -> void:
	var p := tree.get_first_node_in_group("player") as Player
	if p == null:
		return
	if p.get_instance_id() != _player_id:
		_player_id = p.get_instance_id()
		_last_hp = p.health
		return
	if p.health < _last_hp:
		hits_taken += 1
		damage_taken += _last_hp - p.health
		log_event("hurt", {"hp": p.health, "x": roundi(p.global_position.x), "lane": p.current_lane,
			"why": last_why, "near": _nearest_enemy_label(p.global_position)})
	elif p.health > _last_hp:
		heals += 1
		log_event("heal", {"hp": p.health, "x": roundi(p.global_position.x)})
	_last_hp = p.health


## Best guess at who landed a hit: the nearest live enemy ("kind@x/lane").
func _nearest_enemy_label(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for e: Dictionary in _last_snap.get("enemies", []):
		var d := pos.distance_to(Vector2(e["x"], e["y"]))
		if d < best_d:
			best_d = d
			best = "%s@x%d/l%d" % [e.get("kind", "?"), roundi(e["x"]), e["lane"]]
	return best


## Kills the scenario made itself (`kill_all`) are not the player's kills.
func ignore_kill(enemy: Node) -> void:
	_dead_ids[enemy.get_instance_id()] = true


## A step that could not do what it said (walk_to timeout, lane not reached...).
## Any step failure fails the run.
func fail_step(step_text: String, reason: String) -> void:
	step_failures.append({"step": step_text, "reason": reason})
	log_event("step_failed", {"step": step_text, "reason": reason})


## Start measuring forward progress in `dir` (0 stops measuring).
func set_progress_dir(dir: int) -> void:
	progress_dir = dir
	_best_progress = -INF
	_stall_s = 0.0
	_stuck_logged = false


## The brain's reason for its current intent; logged only when it changes, so the
## report shows the decision trail (e.g. "fight: close in" -> "unstick: jump").
func note_why(why: String) -> void:
	if why == last_why:
		return
	last_why = why
	var p: Dictionary = _last_snap.get("player", {})
	log_event("why", {"why": why, "x": roundi(p.get("x", 0.0)), "lane": p.get("lane", -1), "state": p.get("state", "")})


## Scripted hp changes (the `hp` step) are not damage or healing.
func rebase_hp(hp: int) -> void:
	_last_hp = hp


func _track_kills(tree: SceneTree) -> void:
	for e in tree.get_nodes_in_group("enemies"):
		if e is Enemy and e.is_dead and not _dead_ids.has(e.get_instance_id()):
			_dead_ids[e.get_instance_id()] = true
			kills += 1
			log_event("kill", {"kind": e.get_script().resource_path.get_file().get_basename(),
				"x": roundi(e.global_position.x)})


## Stuck = time since the player last set a new best position in progress_dir.
## Measured from position, not from the brain's own timer, so back-off loops and
## scripted walk_to steps that never arrive both count.
func _track_stuck(snap: Dictionary) -> void:
	var p: Dictionary = snap.get("player", {})
	if progress_dir == 0 or p.is_empty() or p.get("dead", false):
		return
	# Standing still to fight (a crowd, the boss) or at the goal is not stuck.
	if last_why.begins_with("fight") or last_why == "at goal" or str(p.get("state", "")) in ["AttackState", "KnockbackState"]:
		return
	var v: float = progress_dir * float(p["x"])
	if v > _best_progress + PROGRESS_PX:
		_best_progress = v
		_stall_s = 0.0
		_stuck_logged = false
		return
	_stall_s += 1.0 / Engine.physics_ticks_per_second
	max_stuck_s = maxf(max_stuck_s, _stall_s)
	if _stall_s < STUCK_LOG_S or _stuck_logged:
		return
	_stuck_logged = true
	var spot := {"x": roundi(p.get("x", 0.0)), "y": roundi(p.get("y", 0.0)), "lane": p.get("lane", 0),
		"scene": _scene.get_file().get_basename(), "why": last_why}
	stuck_spots.append(spot)
	log_event("stuck", spot)
	if _auto_snaps < MAX_AUTO_SNAPS:
		_auto_snaps += 1
		snap("stuck_%d" % stuck_spots.size())


## Windowed runs only. Fire-and-forget: the PNG lands after the next drawn frame.
func snap(label: String) -> String:
	if not can_snap() or out_dir == "":
		log_event("snap", {"name": label, "skipped": "headless"})
		return ""
	var path := out_dir.path_join("%s_%s.png" % [run_name, label])
	_save_after_draw(path)
	snaps.append(path)
	log_event("snap", {"name": label})
	return path


func _save_after_draw(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)


func metrics(tree: SceneTree) -> Dictionary:
	var p: Dictionary = _last_snap.get("player", {})
	return {
		"t": snappedf(t, 0.01), "frames": frames,
		"scene": _scene.get_file().get_basename(),
		"x": roundi(p.get("x", 0.0)), "y": roundi(p.get("y", 0.0)), "lane": p.get("lane", -1),
		"hp": p.get("hp", 0), "max_hp": p.get("max_hp", 0), "state": p.get("state", ""),
		"kills": kills, "damage_taken": damage_taken, "hits_taken": hits_taken, "heals": heals,
		"deaths": deaths, "won": 1 if won else 0,
		"boss_reached": 1 if "boss_room" in scenes else 0,
		"enemies_near": _last_snap.get("enemies", []).size(),
		"max_stuck_s": snappedf(max_stuck_s, 0.1), "stuck_spots": stuck_spots.size(),
		"step_failures": step_failures.size(),
		"errors": errors.script_errors, "engine_errors": errors.engine_errors,
		"warnings": errors.warnings,
		"score": ScoreSystem.score if tree.root.has_node("ScoreSystem") else 0,
	}


func dump(label: String) -> Dictionary:
	var d := {"name": label, "player": _last_snap.get("player", {}),
		"enemies": _last_snap.get("enemies", []), "hearts": _last_snap.get("hearts", []),
		"pickups": _last_snap.get("pickups", []), "goal_x": _last_snap.get("goal_x", INF)}
	log_event("dump", d)
	return d


## Errors grouped by site, most frequent first.
func top_errors(limit: int = 15) -> Array:
	errors.mutex.lock()
	var rows: Array = []
	for k in errors.entries:
		rows.append({"site": k, "count": errors.entries[k]})
	errors.mutex.unlock()
	rows.sort_custom(func(a, b): return a["count"] > b["count"])
	return rows.slice(0, limit)
