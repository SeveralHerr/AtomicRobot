class_name DeathBeat
extends Node

## The beat between the killing blow and the GAME OVER card: the game drops to
## SLOW_SCALE for SLOW_SECONDS of real time, then the level drains to grey over
## GREY_SECONDS. The EndCard awaits play() and only then shows the card, so
## Globals.player_death itself is never delayed (score, door encounters, the boss room
## and the enemies all still react on the blow).
##
## Owns Engine.time_scale while slowing: re-asserts it every frame (a hit-stop or the
## boss's ticketed slow-mo ending mid-beat writes 1.0), hands back 1.0 while the tree
## is paused (the pause menu runs at full speed) and when it leaves the tree.

const SLOW_SCALE := 0.35
const SLOW_SECONDS := 0.6
const GREY_SECONDS := 0.45

## True from play() until the grey is in.
var running := false
## The backdrop shader (shaders/end_card_dim.gdshader) whose grey/dim this tweens.
var material: ShaderMaterial

var _slowing := false


## One beat per death: the EndCard refuses a second signal while `running`.
func play() -> void:
	running = true
	_look(0.0)
	_slow(true)
	# Real time (ignore_time_scale), but pausable: a pause holds the beat.
	await get_tree().create_timer(SLOW_SECONDS, false, false, true).timeout
	_slow(false)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_method(_look, 0.0, 1.0, GREY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	running = false


func _process(_delta: float) -> void:
	if _slowing:
		Engine.time_scale = SLOW_SCALE


func _slow(on: bool) -> void:
	_slowing = on
	Engine.time_scale = SLOW_SCALE if on else 1.0


func _look(amount: float) -> void:
	if material:
		material.set_shader_parameter("grey", amount)
		material.set_shader_parameter("dim", amount)


func _notification(what: int) -> void:
	if not _slowing:
		return
	# Unpausing needs nothing: _process re-asserts SLOW_SCALE on the next frame.
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		Engine.time_scale = 1.0
