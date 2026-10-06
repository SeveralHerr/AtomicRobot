extends Node2D
class_name StreetObjective

## A side job on the street: something to do other than walk right and clear the next
## door — run down a thief, keep the meter maids off the customers' cars. Subclasses
## own the job's rules; this base owns the lifecycle every job shares:
##
##   WAITING --player crosses trigger_x on a quiet street--> RUNNING --> DONE
##
## Starting slams a callout (EncounterAnnouncer, the door fights' text system) and
## slides the goal onto the ObjectiveHud card. Ending happens exactly once: a win pays
## reward_points plus a gold payoff word, a miss gets a softer callout and costs
## nothing — a side job must never cost the run. A death mid-job ends it quietly.
##
## Never soft-locks: no arena lock (the player can walk away and the job just runs out),
## and a watchdog ends the job time_limit + WATCHDOG_SLACK after it started, whatever
## its own rules are still waiting for (cf. BuildingDoorEncounter's watchdog).

signal finished(success: bool)

enum Phase { WAITING, RUNNING, DONE }

## How far past trigger_x the job may still start (world px).
const START_WINDOW := 500.0
## Real seconds past time_limit before the watchdog ends a job its rules left open.
const WATCHDOG_SLACK := 6.0
## Payoff callouts, as EncounterAnnouncer's STREET CLEAR!: burst for a win, stripe for a miss.
const WIN_TINT := ComicStyle.BLUE
const MISS_TINT := ComicStyle.PLUM
const WIN_STING := preload("res://sounds/Unlock.wav")
## Payoff holds: shorter than a door's STREET CLEAR! (reading time, ~3.5 s). The street
## carries on under a job's payoff — the caught thief turns and fights right where the
## burst sits — so it is glanced, not read; the card's stamp keeps the result up.
const WIN_HOLD := 1.8
const MISS_HOLD := 2.2
const HEART := preload("res://scenes/atomic_heart_pickup.tscn")
## Where the heart lands from the player: just ahead, on the walkway line (as the
## door finale's heart: 26 px above the floor).
const HEART_LAND := Vector2(56.0, -26.0)

## Jobs in this group are running (AmbientTraffic holds its clock for them, as for a
## door fight).
const RUNNING := &"street_jobs_running"

## Report name (Globals.objective_finished, autoplay events).
@export var id: String = "objective"
## The job starts once the player's x passes this (in `trigger_dir`).
@export var trigger_x: float = 0.0
@export var trigger_dir: int = 1
## Seconds the player has once the job is on.
@export var time_limit: float = 12.0
@export var reward_points: int = 500
## A win also knocks an atomic heart loose onto the walkway: a reason to bother with a
## side job besides points, and its fights cost health that the boss fight (health
## carries over) would otherwise collect. Off: points only.
@export var reward_heart: bool = true

var phase: Phase = Phase.WAITING
var time_left: float = 0.0
var success: bool = false
var player: Player
var hud: ObjectiveHud
var announcer: EncounterAnnouncer
var _age: float = 0.0


## Pure start rule: just past the mark (within START_WINDOW), and the street is quiet —
## no cut scene has the camera and no scripted fight (a door's arena lock) is live.
## The window means a player who is already well past (a teleport, a debug start) never
## has a job spring up behind them — and in the MeterDefense case, never wins one by
## being too far away for its maids to exist.
static func should_start(px: float, mark: float, dir: int, cutscene: bool, event: bool) -> bool:
	if cutscene or event:
		return false
	return in_window(px, mark, dir)


## Any job running in `tree`.
static func any_running(tree: SceneTree) -> bool:
	return tree.get_first_node_in_group(RUNNING) != null


static func in_window(px: float, mark: float, dir: int) -> bool:
	var past := (px - mark) * signf(dir)
	return past >= 0.0 and past <= START_WINDOW


## Pure watchdog rule: the job has outlived its clock by the slack.
static func overdue(age: float, limit: float) -> bool:
	return age >= limit + WATCHDOG_SLACK


func _ready() -> void:
	Globals.player_death.connect(_on_player_death)


func _process(delta: float) -> void:
	if phase == Phase.WAITING:
		var p := _player()
		if p != null and not p.is_dead and _ready_to_start(p) and should_start(
				p.global_position.x, trigger_x, trigger_dir, MicroCutscene.playing, Globals.event_active()):
			start(p)
		return
	if phase != Phase.RUNNING:
		return
	# A cut scene freezes the fight; the job's clock waits with it.
	if MicroCutscene.playing:
		return
	_age += delta
	if _clock_running():
		time_left = maxf(time_left - delta, 0.0)
	if hud != null:
		hud.set_time(time_left / maxf(time_limit, 0.01))
	_tick(delta)
	if phase != Phase.RUNNING:
		return
	if overdue(_age, time_limit):
		finish(_watchdog_outcome())
	elif time_left <= 0.0 and _clock_running():
		_on_time_up()


func start(p: Player) -> void:
	if phase != Phase.WAITING:
		return
	player = p
	phase = Phase.RUNNING
	add_to_group(RUNNING)
	time_left = time_limit
	_age = 0.0
	# A door's STREET CLEAR! still up would sit under this job's callout (each
	# announcer has its own banner): send it off, as the cut scenes do.
	get_tree().call_group(BossBanner.GROUP, "clear_title")
	announcer = EncounterAnnouncer.new()
	add_child(announcer)
	hud = ObjectiveHud.new()
	add_child(hud)
	_begin()


## End the job once: payoff, points, report, cleanup.
func finish(won: bool) -> void:
	if phase != Phase.RUNNING:
		return
	phase = Phase.DONE
	remove_from_group(RUNNING)
	success = won
	if won:
		ScoreSystem.award(reward_points)
		_play_sting()
		if reward_heart:
			_drop_heart()
	if hud != null:
		hud.close(won, _stamp_word(won))
	_payoff(won)
	_cleanup(won)
	Globals.objective_finished.emit(id, won)
	finished.emit(won)


func _on_player_death() -> void:
	if phase != Phase.RUNNING:
		return
	phase = Phase.DONE
	remove_from_group(RUNNING)
	if hud != null:
		hud.dismiss()
	if announcer != null:
		announcer.visible = false
	_cleanup(false)
	Globals.objective_finished.emit(id, false)
	finished.emit(false)


func _player() -> Player:
	if is_instance_valid(player):
		return player
	return get_tree().get_first_node_in_group("player") as Player


## The heart pops up off the player and bounces down onto the walkway ahead of them.
func _drop_heart() -> void:
	var p := _player()
	var scene := get_tree().current_scene
	if p == null or scene == null or p.lane_floor_y == INF:
		return
	var heart: Node2D = HEART.instantiate()
	scene.add_child(heart)
	heart.global_position = p.global_position + Vector2(0, -40)
	var ahead := float(signi(p.scale.x)) if p.scale.x != 0.0 else 1.0
	var land := Vector2(p.global_position.x + HEART_LAND.x * ahead, p.lane_floor_y + HEART_LAND.y)
	# Not collectable mid-air: it spawns on the player and read as an instant heal.
	var area: Area2D = heart.get_node("Area2D")
	area.set_deferred("monitoring", false)
	var tw := heart.create_tween()
	tw.tween_property(heart, "global_position", land, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(area.set_deferred.bind("monitoring", true))


func _play_sting() -> void:
	var s := AudioStreamPlayer.new()
	s.stream = WIN_STING
	s.volume_db = -6.0
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


# --- Subclass hooks -----------------------------------------------------------------

## Extra start condition on top of should_start (e.g. the lanes exist yet).
func _ready_to_start(p: Player) -> bool:
	return p.lane_floor_y != INF


## The job is on: spawn its actors, slam its callout, open the card.
func _begin() -> void:
	pass


## Per frame while running (after the clock).
func _tick(_delta: float) -> void:
	pass


## False while the job's clock should hold (e.g. before the thief has grabbed anything).
func _clock_running() -> bool:
	return true


func _on_time_up() -> void:
	finish(false)


func _watchdog_outcome() -> bool:
	return false


## The card's stamp: the points on a win (the burst's subtitle is too small to read
## them), the job's own word on a miss.
func _stamp_word(won: bool) -> String:
	return "+%d" % reward_points if won else "MISSED"


## Callout + world word for the outcome.
func _payoff(_won: bool) -> void:
	pass


## Free/hand back everything the job spawned (also on a death).
func _cleanup(_won: bool) -> void:
	pass
