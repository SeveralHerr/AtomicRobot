class_name ScoreTally
extends Node

## The end card's FINAL SCORE count-up: the number rolls from 0 to the run's total
## with an arcade coin tick that climbs in pitch, then `finished` fires so the rank
## stamp can slam on the last tick. The value curve and the pitch ramp are static so
## the tests pin them without timing a tween.

signal finished

const SECONDS := 0.9
## Coin ticks per tally: enough to read as counting, few enough not to buzz.
const TICKS := 12
const PITCH_FROM := 0.9
const PITCH_TO := 1.6
const TICK_SOUND: AudioStream = preload("res://Sounds/coin.wav")

var label: Label
var total: int = 0
var _tween: Tween
var _ticks_played := 0
var _audio: AudioStreamPlayer


## Shown value at progress `k` (0..1): ease-out, so it races then settles on `total`.
static func value_at(k: float, to: int) -> int:
	var t := clampf(k, 0.0, 1.0)
	return roundi(to * (1.0 - pow(1.0 - t, 3.0)))


## Pitch of tick `i` of `TICKS`: climbs to the last one.
static func tick_pitch(i: int) -> float:
	return lerpf(PITCH_FROM, PITCH_TO, clampf(float(i) / (TICKS - 1), 0.0, 1.0))


func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.stream = TICK_SOUND
	_audio.volume_db = -10.0
	add_child(_audio)


## Roll `on` from 0 to `to` after `delay`. A second call restarts the roll.
func play(on: Label, to: int, delay: float = 0.0) -> void:
	label = on
	total = to
	_ticks_played = 0
	if _tween:
		_tween.kill()
	_set_progress(0.0)
	_tween = create_tween()
	_tween.tween_interval(delay)
	_tween.tween_method(_set_progress, 0.0, 1.0, SECONDS)
	_tween.tween_callback(func() -> void: finished.emit())


## Jump to the end (repaint, tests): final number, no ticks, `finished` fires.
func finish() -> void:
	if _tween:
		_tween.kill()
	_ticks_played = TICKS
	_set_progress(1.0)
	finished.emit()


func is_running() -> bool:
	return _tween != null and _tween.is_running()


func _set_progress(k: float) -> void:
	if label:
		label.text = ComicStyle.format_score(value_at(k, total))
	# A tick each time progress crosses the next 1/TICKS step.
	var due := floori(k * TICKS)
	if due > _ticks_played and _ticks_played < TICKS and _audio and _audio.is_inside_tree():
		_audio.pitch_scale = tick_pitch(_ticks_played)
		_audio.play()
		_ticks_played = mini(due, TICKS)
