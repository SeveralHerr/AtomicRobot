extends RefCounted
class_name EnemyTelegraph

## Wind-up tell: the maid glows gold from the start of a swing — pulse, dip, then
## lit on the release frame — so "she is about to throw" reads early enough to
## step a lane.
##
## Every maid sprite runs shaders/flash.gdshader, which overwrites COLOR, so
## modulate/self_modulate never reach the screen. The tell uses that shader's tint
## uniforms (buff_*: the power-up overlay, which only the player ever uses); the Hit
## flash (flash_value) still wins on top. Sprites without the shader fall back to
## self_modulate.

const TELL_COLOR := Color(1.0, 0.82, 0.25)
## Tint strength at the pulse peaks / the held release pose.
const PULSE := 0.45
const HOLD := 0.55
## Below this a wind-up is too short to pulse; it just lights up.
const MIN_SECONDS := 0.1
const PARAM := "material:shader_parameter/buff_value"


static func _shader(sprite: CanvasItem) -> ShaderMaterial:
	var mat := sprite.material as ShaderMaterial
	if mat == null or mat.shader == null:
		return null
	for u in mat.shader.get_shader_uniform_list():
		if u["name"] == "buff_value":
			return mat
	return null


## Pulse, dip, then ramp to HOLD by release. `seconds` is wind-up to release.
static func wind_up(sprite: CanvasItem, seconds: float) -> Tween:
	var quarter := maxf(seconds, MIN_SECONDS) * 0.25
	var tw := sprite.create_tween()
	var mat := _shader(sprite)
	if mat == null:
		var lit := Color(1.0 + TELL_COLOR.r, 1.0 + TELL_COLOR.g, 1.0 + TELL_COLOR.b) * 0.8
		tw.tween_property(sprite, "self_modulate", lit, quarter)
		tw.tween_property(sprite, "self_modulate", Color.WHITE, quarter)
		tw.tween_property(sprite, "self_modulate", lit, quarter * 2.0)
		return tw
	mat.set_shader_parameter("buff_color", TELL_COLOR)
	mat.set_shader_parameter("buff_pulse_hz", 0.0)
	mat.set_shader_parameter("buff_pixel_size", 0.0)
	mat.set_shader_parameter("buff_value", 0.0)
	tw.tween_property(sprite, PARAM, PULSE, quarter)
	tw.tween_property(sprite, PARAM, 0.0, quarter)
	tw.tween_property(sprite, PARAM, HOLD, quarter * 2.0)
	return tw


## Stop a tell (released, interrupted or killed) and restore the sprite.
static func clear(sprite: CanvasItem, tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()
	if not is_instance_valid(sprite):
		return
	sprite.self_modulate = Color.WHITE
	var mat := _shader(sprite)
	if mat != null:
		mat.set_shader_parameter("buff_value", 0.0)


## Current tell strength 0..1 (for tests and the HUD readout).
static func strength(sprite: CanvasItem) -> float:
	var mat := _shader(sprite)
	if mat != null:
		return float(mat.get_shader_parameter("buff_value"))
	return clampf(sprite.self_modulate.r - 1.0, 0.0, 1.0)


## Seconds from frame 0 to `release_frame` of `clip` at `speed` playback.
static func seconds_to_frame(frames: SpriteFrames, clip: String, release_frame: int, speed: float) -> float:
	if frames == null or not frames.has_animation(clip):
		return 0.0
	var fps := frames.get_animation_speed(clip) * maxf(speed, 0.01)
	var total := 0.0
	for i in mini(release_frame, frames.get_frame_count(clip)):
		total += frames.get_frame_duration(clip, i) / fps
	return total
