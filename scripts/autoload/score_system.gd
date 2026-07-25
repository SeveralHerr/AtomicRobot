extends Node

## Live per-stage scoring: combo meter, stage clock, damage tally, end-of-stage rank.
##
## All balance numbers live in scripts/score_rules.gd — this file only tracks state
## and decides WHEN things happen. Autoload for the same reasons as PowerupSystem:
## the Player and the HUD are both replaced on every scene load, and the run's score
## has to outlive both.
##
## Stage boundaries are detected by watching the current scene rather than by having
## levels call begin/end. Levels are edited by hand in the editor and a forgotten
## call would silently produce a stage that never scores; polling the scene path
## cannot be forgotten.

signal score_changed(score: int)
signal combo_changed(combo: int, multiplier: int)
signal stage_started(scene_path: String)
## Emitted once per finished stage with the full ScoreRules.summarise() breakdown,
## plus "scene", "best" and "is_new_best".
signal stage_finished(result: Dictionary)

const SAVE_PATH := "user://scores.cfg"
const SAVE_SECTION := "best"
const SCORE_UI: PackedScene = preload("res://scenes/score_ui.tscn")

var score: int = 0
var combo: int = 0
var stage_seconds: float = 0.0
var damage_taken: int = 0
var running: bool = false
var current_scene_path: String = ""

var _combo_timer: float = 0.0
## Guards against a second finish for the same stage — Globals.boss_death is emitted
## from the boss's death animation and nothing stops it firing twice.
var _finished: bool = false
var _best: ConfigFile = ConfigFile.new()
## Instance id of the scene the current stage belongs to. Keyed on the INSTANCE, not
## the path: the two most common restarts in this game (the devtools start_game verb,
## and retrying after a death) both reload the scene that is already loaded, so a
## path comparison sees no change and would leave the clock running from the previous
## attempt and the HUD parented to the freed scene.
var _scene_id: int = 0
## The injected HUD. Freed along with the scene it was added to, so every use is
## guarded by is_instance_valid rather than by clearing this on scene change.
var _hud: CanvasLayer = null


func _ready() -> void:
	_best.load(SAVE_PATH)
	Globals.meter_maid_death.connect(register_kill)
	Globals.meter_maid_boss_death.connect(register_kill)
	Globals.boss_death.connect(_on_boss_death)
	Globals.player_death.connect(_on_player_death)


func _process(delta: float) -> void:
	_track_scene()
	if not running:
		return
	stage_seconds += delta
	if combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_reset_combo()


## Start/stop scoring as the current scene changes. Cheap: one int compare a frame.
##
## A scene swap leaves current_scene null for a frame, which reads as id 0 and stops
## scoring until the replacement arrives — correct, and self-healing.
func _track_scene() -> void:
	var scene := get_tree().current_scene
	var id := scene.get_instance_id() if scene != null else 0
	if id == _scene_id:
		return
	_scene_id = id
	current_scene_path = scene.scene_file_path if scene != null else ""
	var path := current_scene_path
	if ScoreRules.is_scored_scene(path):
		begin_stage(path)
	else:
		running = false


## Reset every counter and start the clock. Called automatically on entering a scored
## scene; exposed for the devtools verb and for a retry that reloads the same scene.
func begin_stage(scene_path: String = current_scene_path) -> void:
	score = 0
	combo = 0
	stage_seconds = 0.0
	damage_taken = 0
	_combo_timer = 0.0
	_finished = false
	running = true
	# Before the signals below: add_child runs the HUD's _ready synchronously, so it
	# is already subscribed by the time stage_started goes out.
	_ensure_hud()
	stage_started.emit(scene_path)
	score_changed.emit(score)
	combo_changed.emit(combo, multiplier())


## Put the HUD into the running level if it isn't already there.
##
## Injected rather than authored into each level: the HUD is driven entirely by this
## autoload's signals, so there is nothing to wire per level, and one injection point
## covers main.tscn, boss_room.tscn and every sandbox under test/scenes/ instead of
## three copies that drift apart. It goes on the scene root (its own CanvasLayer at
## layer 3) so it does not depend on any level's UI node layout.
func _ensure_hud() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if _hud != null and is_instance_valid(_hud) and _hud.get_parent() == scene:
		return
	_hud = SCORE_UI.instantiate()
	scene.add_child(_hud)


func multiplier() -> int:
	return ScoreRules.multiplier_for(combo)


## Fraction of the combo window still left (1.0 just after a hit, 0.0 at the break).
## The HUD draws this as a draining bar; returns 0.0 with no combo running.
func combo_fraction() -> float:
	if combo <= 0:
		return 0.0
	return clampf(_combo_timer / ScoreRules.COMBO_WINDOW, 0.0, 1.0)


## The player connected with an enemy. Routed through Player.land_hit() so melee and
## both projectile characters all count.
func register_hit() -> void:
	if not running:
		return
	combo += 1
	_combo_timer = ScoreRules.COMBO_WINDOW
	_add(ScoreRules.hit_points(combo))
	combo_changed.emit(combo, multiplier())


## An enemy died. Connected to Globals.meter_maid_death, so hazard kills (a car
## flattening a maid) count too — which is intended, that is a legitimate tactic.
func register_kill() -> void:
	if not running:
		return
	# A kill refreshes the window without advancing the count: the killing blow was
	# already counted by register_hit(), and counting it twice would let a single
	# swing that finishes an enemy jump two combo tiers.
	_combo_timer = ScoreRules.COMBO_WINDOW
	_add(ScoreRules.kill_points(combo))


## The player took a hit: the combo is gone. Called from Player.take_damage(), which
## every damage source already funnels through (and which returns early in god_mode,
## so the debug cheat cannot cost you a combo).
func register_player_damaged() -> void:
	if not running:
		return
	damage_taken += 1
	_reset_combo()


func _add(points: int) -> void:
	score += points
	score_changed.emit(score)


func _reset_combo() -> void:
	if combo == 0:
		return
	combo = 0
	_combo_timer = 0.0
	combo_changed.emit(combo, multiplier())


func _on_player_death() -> void:
	# A death ends the run without a rank card — you do not get graded on a stage you
	# did not finish.
	running = false
	_reset_combo()


func _on_boss_death() -> void:
	finish_stage()


## Close the stage out, emit the breakdown, and persist it if it beat the record.
## Safe to call twice; only the first call for a stage does anything.
func finish_stage() -> Dictionary:
	if _finished or not running:
		return {}
	_finished = true
	running = false
	var health := 0
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		health = maxi(0, player.health)
	var result := ScoreRules.summarise(score, stage_seconds, damage_taken, health)
	var previous := best_for(current_scene_path)
	var is_new_best: bool = int(result["total"]) > previous
	result["scene"] = current_scene_path
	result["best"] = maxi(previous, int(result["total"]))
	result["is_new_best"] = is_new_best
	if is_new_best:
		_save_best(current_scene_path, int(result["total"]), String(result["rank"]))
	stage_finished.emit(result)
	return result


func best_for(scene_path: String) -> int:
	return int(_best.get_value(SAVE_SECTION, scene_path + "/score", 0))


func best_rank_for(scene_path: String) -> String:
	return String(_best.get_value(SAVE_SECTION, scene_path + "/rank", ""))


func _save_best(scene_path: String, total: int, rank: String) -> void:
	_best.set_value(SAVE_SECTION, scene_path + "/score", total)
	_best.set_value(SAVE_SECTION, scene_path + "/rank", rank)
	var err := _best.save(SAVE_PATH)
	if err != OK:
		push_warning("ScoreSystem: could not save best score (%d)" % err)


## Wipe every stored best. Used by the devtools verb; there is deliberately no
## in-game path to this.
func clear_records() -> void:
	_best.clear()
	_best.save(SAVE_PATH)
