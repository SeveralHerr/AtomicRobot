extends Node

## Live run scoring: combo meter, run clock, damage tally, secrets, end-of-run rank.
##
## A RUN is the street then the boss room: walking out of the street alive (through
## the boss door) carries the score, clock, damage and secrets into the boss stage
## (ScoreRules.continues_run); every other stage start begins a fresh run.
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
const TABLE_SECTION := "high_scores"
const TABLE_KEY := "entries"
const LAST_INITIALS_KEY := "last_initials"
const SCORE_UI: PackedScene = preload("res://scenes/score_ui.tscn")

var score: int = 0
var combo: int = 0
var stage_seconds: float = 0.0
var damage_taken: int = 0
var running: bool = false
var current_scene_path: String = ""
## Swappable so tests never touch the player's real save.
var save_path: String = SAVE_PATH
## The arcade list, best first. See HighScoreTable for the entry shape.
var high_scores: Array = []
## True from a qualifying run until submit_initials(). The end card shows the
## initials entry instead of the list while this is set.
var awaiting_initials: bool = false
## How the last run ended, for the end card. Written on a clear or a death BEFORE the
## level's own handlers run (this autoload connects to Globals first):
## {"won", "total", "rank" ("" on a death), "slot" (-1 = not on the list), plus the
## ScoreRules.summarise() breakdown on a clear}.
var last_run: Dictionary = {}
## Pre-filled on the next entry, so a regular only confirms their initials.
var last_initials: String = HighScoreTable.DEFAULT_INITIALS
## The part of `score` banked on the street before the boss door; 0 on a fresh stage.
var street_score: int = 0
## Secrets claimed this run (Globals.secret_found).
var secrets := SecretTally.new()
var _pending: Dictionary = {}
## Characters still locked when the run began: any of them unlocked by the end is
## this run's unlock, shown on the YOU WIN card.
var _locked_at_start: PackedStringArray = []

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
## The scored scene a live run just walked out of, until the next real scene decides
## whether the run continues there.
var _carry_from: String = ""
## The injected HUD. Freed along with the scene it was added to, so every use is
## guarded by is_instance_valid rather than by clearing this on scene change.
var _hud: CanvasLayer = null


func _ready() -> void:
	reload()
	Globals.meter_maid_death.connect(register_kill)
	Globals.meter_maid_boss_death.connect(register_kill)
	Globals.boss_death.connect(_on_boss_death)
	Globals.player_death.connect(_on_player_death)
	Globals.secret_found.connect(_on_secret_found)


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
	enter_scene(scene.scene_file_path if scene != null else "", scene != null)


## A new scene became current (`exists` false for the empty frame of a swap). Leaving
## the street alive arms the carry; the swap's empty frame keeps it; the next real
## scene either continues the run (the boss room) or drops it.
func enter_scene(path: String, exists: bool = true) -> void:
	if running and current_scene_path != "":
		_carry_from = current_scene_path
	current_scene_path = path
	if ScoreRules.is_scored_scene(path):
		begin_stage(path, ScoreRules.continues_run(_carry_from, path))
		_carry_from = ""
	else:
		running = false
		if exists:
			_carry_from = ""


## Start the clock for a stage. A fresh run resets every counter; `continue_run` (the
## boss room entered from the street) keeps the run's score, clock, damage and secrets
## and banks the score so far as the street's. Called automatically on entering a
## scored scene; exposed for the devtools verb and for a retry that reloads the scene.
func begin_stage(scene_path: String = current_scene_path, continue_run: bool = false) -> void:
	if continue_run:
		street_score = score
	else:
		score = 0
		stage_seconds = 0.0
		damage_taken = 0
		street_score = 0
		secrets.clear()
		_locked_at_start = _locked_characters()
	combo = 0
	_combo_timer = 0.0
	_finished = false
	running = true
	# A restart in the middle of entering initials abandons that offer.
	_pending = {}
	awaiting_initials = false
	last_run = {}
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
## layer 1, under the level UI at 2 so the EndCard covers it) so it does not
## depend on any level's UI node layout.
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


## Flat points for finishing a street side job (StreetObjective). Not multiplied by the
## combo: the job is its own reward, and a combo already pays the fight inside it.
func award(points: int) -> void:
	if running and points > 0:
		_add(points)


func _add(points: int) -> void:
	score += points
	score_changed.emit(score)


func _reset_combo() -> void:
	if combo == 0:
		return
	combo = 0
	_combo_timer = 0.0
	combo_changed.emit(combo, multiplier())


func _on_secret_found(kind: String, id: String) -> void:
	if running:
		secrets.record(kind, id)


func _locked_characters() -> PackedStringArray:
	var out := PackedStringArray()
	for c in Globals.character_dict:
		if not Globals.character_dict[c].unlocked:
			out.append(c)
	return out


## Characters unlocked since the run began, in roster order.
func run_unlocks() -> PackedStringArray:
	var out := PackedStringArray()
	for c in _locked_at_start:
		if Globals.character_dict.has(c) and Globals.character_dict[c].unlocked:
			out.append(c)
	return out


func _on_player_death() -> void:
	# A death ends the run without a rank card — you do not get graded on a stage you
	# did not finish — but a big enough score still goes on the board, arcade-style.
	if running:
		last_run = {"won": false, "total": score, "rank": "", "street_score": street_score}
		_offer_high_score(score, "")
	running = false
	_reset_combo()


func _on_boss_death() -> void:
	finish_stage()


## Close the run out, emit the breakdown, and persist it if it beat the record.
## Safe to call twice; only the first call for a stage does anything.
func finish_stage() -> Dictionary:
	if _finished or not running:
		return {}
	_finished = true
	running = false
	# Scored in ORBS, not raw hit points: the player is rewarded for the health bar
	# they can see, and it keeps POINTS_PER_HEALTH_KEPT * max health under
	# PERFECT_BONUS (the invariant test_score_rules.gd asserts).
	var orbs_left := 0
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		orbs_left = Player.orbs_for(player.health)
	var result := ScoreRules.summarise(score, stage_seconds, damage_taken, orbs_left,
		ScoreRules.PAR_SECONDS, secrets.found_total(), street_score)
	result["secrets"] = secrets.counts()
	# The card's "a/b": only the real run has a level to count secrets in.
	result["secret_totals"] = SecretTally.totals_in(ScoreRules.SCORED_SCENES) 		if current_scene_path in ScoreRules.SCORED_SCENES else {}
	result["unlocks"] = Array(run_unlocks())
	var previous := best_for(current_scene_path)
	var is_new_best: bool = int(result["total"]) > previous
	result["scene"] = current_scene_path
	result["best"] = maxi(previous, int(result["total"]))
	result["is_new_best"] = is_new_best
	if is_new_best:
		_save_best(current_scene_path, int(result["total"]), String(result["rank"]))
	last_run = result.duplicate()
	last_run["won"] = true
	_offer_high_score(int(result["total"]), String(result["rank"]))
	stage_finished.emit(result)
	return result


func best_for(scene_path: String) -> int:
	return int(_best.get_value(SAVE_SECTION, scene_path + "/score", 0))


func best_rank_for(scene_path: String) -> String:
	return String(_best.get_value(SAVE_SECTION, scene_path + "/rank", ""))


func _save_best(scene_path: String, total: int, rank: String) -> void:
	_best.set_value(SAVE_SECTION, scene_path + "/score", total)
	_best.set_value(SAVE_SECTION, scene_path + "/rank", rank)
	_save()


func _save() -> void:
	_best.set_value(TABLE_SECTION, TABLE_KEY, high_scores)
	_best.set_value(TABLE_SECTION, LAST_INITIALS_KEY, last_initials)
	var err := _best.save(save_path)
	if err != OK:
		push_warning("ScoreSystem: could not save scores (%d)" % err)


## Re-read the save file. The list goes through HighScoreTable.from_variant because
## the file is user-editable: junk rows are dropped, initials re-sanitised.
func reload() -> void:
	_best = ConfigFile.new()
	_best.load(save_path)
	high_scores = HighScoreTable.from_variant(_best.get_value(TABLE_SECTION, TABLE_KEY, []))
	last_initials = HighScoreTable.sanitize_initials(str(_best.get_value(TABLE_SECTION, LAST_INITIALS_KEY, "")))


# --- High-score list ---------------------------------------------------------

func _offer_high_score(total: int, rank: String) -> void:
	last_run["slot"] = -1
	# Ranked scenes only: the enemy sandboxes score for tests, not for the list.
	if not current_scene_path in ScoreRules.SCORED_SCENES:
		return
	var slot := HighScoreTable.slot_for(high_scores, total)
	if slot < 0:
		return
	last_run["slot"] = slot
	_pending = {"score": total, "rank": rank}
	awaiting_initials = true


## Write the pending run under `initials`. Returns its row, or -1 when there is no
## pending run (already submitted, or a restart dropped it).
func submit_initials(initials: String) -> int:
	if _pending.is_empty():
		return -1
	var entry := HighScoreTable.make_entry(initials, int(_pending["score"]), String(_pending["rank"]))
	_pending = {}
	awaiting_initials = false
	last_initials = String(entry["initials"])
	var slot := HighScoreTable.insert(high_scores, entry)
	_save()
	return slot


## Wipe every stored best. Used by the devtools verb; there is deliberately no
## in-game path to this.
func clear_records() -> void:
	_best.clear()
	high_scores.clear()
	last_initials = HighScoreTable.DEFAULT_INITIALS
	_best.save(save_path)
