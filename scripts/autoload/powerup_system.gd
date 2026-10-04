extends Node

## Runtime for timed power-ups: owns the countdowns, applies the stat multipliers to
## the live Player, and drives the buff_* uniforms on the character sprite's shader.
##
## Definitions and all the pure math live in scripts/powerup_rules.gd. Nothing in
## this file decides balance — it only applies what PowerupRules says.
##
## Autoload, not a node on the player, for two reasons: the Player instance is
## replaced outright on every scene reload (so a per-player timer would be a fresh
## object with no way to report what was running), and the HUD needs one stable
## signal source to subscribe to that outlives any single level.

signal powerup_started(id: String, duration: float)
signal powerup_ended(id: String)
## Any change to the active set or its remaining times — the HUD's redraw trigger.
signal powerups_changed()

const FLASH_SHADER: Shader = preload("res://shaders/flash.gdshader")

## id -> seconds remaining. Insertion order is not relied on; active_ids() imposes
## PowerupRules.IDS order so the HUD and the shader blend are deterministic.
var _active: Dictionary = {}
var _player: Player = null
var _sprite: AnimatedSprite2D = null
## Kills since the last drop, for PowerupRules' pity floor. Lives here rather than on
## the enemy because it is a property of the run, and enemies are created and freed
## constantly.
var _kills_since_drop: int = 0
## True when the last _apply() left non-neutral values on the player/shader, so a
## fully-expired set still gets one final write that resets them.
var _needs_reset: bool = false
## Set by the boss door: the next attach() is the same run's boss-room Player, so it
## keeps the street's buffs (like Globals.carried_health) instead of wiping them.
var _carry: bool = false
## Countdowns frozen — the boss room holds them while its intro has the player frozen.
var _held: bool = false


## Bind to the live player and take over its sprite material's shader.
##
## Called from Player._ready(). The player node is INLINED into player.tscn,
## main.tscn and boss_room.tscn, each with its own embedded copy of the flash shader,
## so patching the three scene files would be three edits that silently rot the next
## time someone re-inlines the player. Swapping the Shader on the existing
## ShaderMaterial at runtime fixes every copy at once and — crucially — keeps the
## SAME material object, so the "Hit" AnimationPlayer tracks that write
## `DefaultSprite:material:shader_parameter/flash_value` keep resolving.
func attach(player: Player) -> void:
	_player = player
	_sprite = player.default_sprite if player != null else null
	# A new Player means a new run: drop any buff left over from the previous life
	# and give the drop table a clean pity count — unless it walked through the boss door.
	if not _carry:
		_active.clear()
		_kills_since_drop = 0
	_carry = false
	_install_shader()
	_apply()
	powerups_changed.emit()


func _install_shader() -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		return
	var mat := _sprite.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		_sprite.material = mat
	if mat.shader != FLASH_SHADER:
		mat.shader = FLASH_SHADER
	# Swapping the shader clears the parameters that were set on the old one, and an
	# unset `flash_color` reads as transparent black — which would turn every hit
	# flash into a hit *blackout*. The scene files all authored it white; restate it.
	mat.set_shader_parameter("flash_color", Color.WHITE)
	mat.set_shader_parameter("flash_value", 0.0)


## The street Player walked through the boss door: hand its buffs to the next one.
func carry_through_door() -> void:
	_carry = true


## Freeze (true) or resume (false) every countdown. Buffs stay applied either way.
func hold(on: bool) -> void:
	_held = on


func is_held() -> bool:
	return _held


func _process(delta: float) -> void:
	if _held:
		return
	if _active.is_empty():
		if _needs_reset:
			_apply()
		return
	var expired: Array[String] = []
	for id in _active.keys():
		_active[id] = float(_active[id]) - delta
		if float(_active[id]) <= 0.0:
			expired.append(id)
	for id in expired:
		_active.erase(id)
	_apply()
	for id in expired:
		powerup_ended.emit(id)
	powerups_changed.emit()


## Start `id`, or refresh it to its full duration if it is already running.
## Refreshing rather than stacking keeps a lucky double-drop from producing a
## 16-second Rage that trivialises a whole encounter.
func grant(id: String) -> bool:
	if not PowerupRules.has_id(id):
		return false
	var was_active := _active.has(id)
	_active[id] = PowerupRules.duration(id)
	_apply()
	if not was_active:
		powerup_started.emit(id, PowerupRules.duration(id))
	powerups_changed.emit()
	return true


func clear_all() -> void:
	if _active.is_empty():
		return
	var ended := active_ids()
	_active.clear()
	_apply()
	for id in ended:
		powerup_ended.emit(id)
	powerups_changed.emit()


func is_active(id: String) -> bool:
	return _active.has(id)


## Seconds left on `id`, or 0.0 if it is not running.
func remaining(id: String) -> float:
	return maxf(0.0, float(_active.get(id, 0.0)))


## Active ids in PowerupRules.IDS order (not Dictionary insertion order), so the HUD
## row order and the shader colour blend are stable regardless of pickup sequence.
func active_ids() -> Array[String]:
	var out: Array[String] = []
	for id in PowerupRules.IDS:
		if _active.has(id):
			out.append(id)
	return out


## Rolls the drop table for one defeated enemy. Returns the power-up id to drop, or
## "" for no drop. Owns the pity counter, so it must be called EXACTLY ONCE per kill.
func roll_drop() -> String:
	if not PowerupRules.should_drop(_kills_since_drop, randf()):
		_kills_since_drop += 1
		return ""
	_kills_since_drop = 0
	return PowerupRules.pick(randf())


func kills_since_drop() -> int:
	return _kills_since_drop


## Push the current active set onto the player and the sprite shader. Idempotent, so
## it is safe to call from every entry point that can change the set.
func _apply() -> void:
	var ids := active_ids()
	var stats := PowerupRules.stack(ids)
	if _player != null and is_instance_valid(_player):
		_player.damage_multiplier = float(stats["damage_multiplier"])
		_player.speed_multiplier = float(stats["speed_multiplier"])
	if _sprite != null and is_instance_valid(_sprite):
		# Drives attack rate: an attack lasts exactly as long as its animation (see
		# AttackState), so speeding the sprite up genuinely raises DPS rather than
		# just looking faster. It speeds walk/run frames too, which is the intent —
		# Overclock should read as the whole character running hot.
		_sprite.speed_scale = float(stats["attack_speed_multiplier"])
		var entries: Array = []
		for id in ids:
			entries.append({
				"id": id,
				"strength": PowerupRules.ramp_strength(remaining(id), PowerupRules.duration(id)),
			})
		var params := PowerupRules.shader_params(entries)
		var mat := _sprite.material as ShaderMaterial
		if mat != null:
			for key in params:
				mat.set_shader_parameter(key, params[key])
	_needs_reset = not ids.is_empty()
