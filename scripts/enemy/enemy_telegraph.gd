extends RefCounted
class_name EnemyTelegraph

## Wind-up tell: the sprite pulses warm-bright from the start of a swing and is
## lit on the release frame, so "she is about to throw" reads early enough to
## step a lane. Uses self_modulate — the Hit flash is a shader param and the
## death blink is modulate, so the three never fight over one property.

const TELL_COLOR := Color(1.9, 1.6, 0.6)
## Below this a wind-up is too short to pulse twice; it just lights up.
const MIN_SECONDS := 0.1


## Pulse, dip, then hold lit until release. `seconds` is wind-up to release.
static func wind_up(sprite: CanvasItem, seconds: float) -> Tween:
	var quarter := maxf(seconds, MIN_SECONDS) * 0.25
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "self_modulate", TELL_COLOR, quarter)
	tw.tween_property(sprite, "self_modulate", Color.WHITE, quarter)
	tw.tween_property(sprite, "self_modulate", TELL_COLOR, quarter)
	return tw


## Stop a tell (released, interrupted or killed) and restore the sprite.
static func clear(sprite: CanvasItem, tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()
	if is_instance_valid(sprite):
		sprite.self_modulate = Color.WHITE


## Seconds from frame 0 to `release_frame` of `clip` at `speed` playback.
static func seconds_to_frame(frames: SpriteFrames, clip: String, release_frame: int, speed: float) -> float:
	if frames == null or not frames.has_animation(clip):
		return 0.0
	var fps := frames.get_animation_speed(clip) * maxf(speed, 0.01)
	var total := 0.0
	for i in mini(release_frame, frames.get_frame_count(clip)):
		total += frames.get_frame_duration(clip, i) / fps
	return total
