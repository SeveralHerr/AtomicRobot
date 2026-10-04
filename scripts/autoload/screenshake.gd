extends Node

## Camera shake for the active Camera2D (autoload `ScreenShake`).
##
## One shake runs at a time. A new request keeps the STRONGER of the current
## amplitude and the new strength, and the LONGER of the remaining and the new
## duration — a small hit landing during a big crash must not cut the crash short.
## Amplitude falls off quadratically to exactly 0, then the camera offset is put
## back where it was. Time is real (unscaled), so a shake during boss slow-mo isn't
## stretched; a hitstop (time_scale 0) holds it.

## Hard cap in px — the same ceiling atomic-pinball uses (SHAKE_PX).
const MAX_STRENGTH := 16.0
const DEFAULT_DURATION := 0.3

## Camera to shake. Null in game: the viewport's active camera is used. Tests inject one.
var camera: Camera2D

var _rng := RandomNumberGenerator.new()
var _target: Camera2D
var _rest := Vector2.ZERO
var _peak := 0.0
var _duration := 0.0
var _elapsed := 0.0


## Strength at `elapsed` of a shake that started at `peak` and lasts `duration`.
static func amplitude(peak: float, elapsed: float, duration: float) -> float:
	if duration <= 0.0 or elapsed >= duration:
		return 0.0
	var k := 1.0 - elapsed / duration
	return peak * k * k


func apply_shake(strength: float = 1.0, duration: float = DEFAULT_DURATION) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	var cam := _resolve_camera()
	if cam == null:
		return
	if cam != _target:
		stop()
		_target = cam
		_rest = cam.offset
	_peak = minf(maxf(current_strength(), strength), MAX_STRENGTH)
	_duration = maxf(remaining(), duration)
	_elapsed = 0.0


func current_strength() -> float:
	return amplitude(_peak, _elapsed, _duration) if is_shaking() else 0.0


func remaining() -> float:
	return maxf(_duration - _elapsed, 0.0) if is_shaking() else 0.0


func is_shaking() -> bool:
	return _target != null and is_instance_valid(_target)


## End the shake now and put the camera back.
func stop() -> void:
	if is_shaking():
		_target.offset = _rest
	_target = null
	_peak = 0.0
	_duration = 0.0
	_elapsed = 0.0


func _process(delta: float) -> void:
	# Undo time_scale: shakes run on real time. At 0 (hitstop) the shake holds.
	step(delta / Engine.time_scale if Engine.time_scale > 0.0 else 0.0)


## Advance the shake by `real_delta` seconds. Public so tests can step it by hand.
func step(real_delta: float) -> void:
	if _target == null:
		return
	if not is_instance_valid(_target):
		_target = null
		return
	_elapsed += real_delta
	if _elapsed >= _duration:
		stop()
		return
	var a := current_strength()
	_target.offset = _rest + Vector2(_rng.randf_range(-a, a), _rng.randf_range(-a, a))


func _resolve_camera() -> Camera2D:
	if camera != null and is_instance_valid(camera):
		return camera
	var vp := get_viewport()
	return vp.get_camera_2d() if vp != null else null
