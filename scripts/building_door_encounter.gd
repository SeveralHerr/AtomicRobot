extends Node2D
class_name BuildingDoorEncounter

## TMNT-style "enemies burst out of a building" encounter.
##
## Walk into the trigger, the door bursts open, a squad pours out and fans across
## the lanes, and — if `lock_arena` — barriers plus camera limits hold the player
## there until the street is clear.
##
## `DoorMouth/Crack` (sprites/crack.png) doubles as the visual: a hairline crack
## sits at the base of the wall as a permanent tell for where an encounter lives,
## widens through the telegraph, and blows open into a hole enemies pour out of.

signal encounter_finished

@export var enemy_count: int = 5
## Fraction of the squad that spawns as melee maids. Ranged maids run FindMeterState
## when they run dry, which walks them into a barrier if no meter is inside the
## arena — so keep this high unless the encounter is placed near parking meters.
@export_range(0.0, 1.0) var melee_ratio: float = 0.75
@export var spawn_interval: float = 0.25
## Barriers + camera limits while the fight is live. Off = burst with no lock.
@export var lock_arena: bool = true
## Half-width of the locked arena in world px. Must exceed 256 — the camera shows
## 512 px of world at zoom 2.5, so anything smaller never binds.
@export var arena_half_width: int = 320
## Force-release after this long, so a stuck enemy can never softlock the player.
@export var watchdog_seconds: float = 45.0
## Free the whole node once the street is clear. Off by default: the burst-open
## crack (final frame, a hole) is left in the wall as a permanent level scar
## instead of vanishing along with the encounter's logic.
@export var one_shot: bool = false
## Seconds a spawned enemy holds its spawn lane before it starts chasing the
## player's lane. Without this the whole squad re-stacks onto one lane in ~1.5s
## and the fan-out never reads.
@export var lane_hold_min: float = 1.5
@export var lane_hold_max: float = 4.0
## Telegraph (door rattle) before the burst.
@export var arm_seconds: float = 0.35
## Optional explicit lane order, e.g. [0, 2, 1, 3]. Empty = round-robin all lanes.
@export var lane_pattern: Array[int] = []

@onready var door_mouth: Marker2D = $DoorMouth
@onready var crack: AnimatedSprite2D = $DoorMouth/Crack
@onready var dust: CPUParticles2D = $Dust
@onready var trigger: Area2D = $Trigger
@onready var left_wall: CollisionShape2D = $Barriers/LeftWall/CollisionShape2D
@onready var right_wall: CollisionShape2D = $Barriers/RightWall/CollisionShape2D
@onready var door_slam: AudioStreamPlayer2D = $DoorSlam

var player: Player
var _fired: bool = false
var _active: bool = false
## True from the burst until the last enemy has been spawned. The completion check
## must not run during this window — `_spawned` is legitimately empty at the start
## and would otherwise end the encounter on the first frame.
var _spawning: bool = false
var _pushed_event: bool = false
var _spawned: Array[Node2D] = []
var _saved_limit_left: int = 0
var _saved_limit_right: int = 0
var _watchdog: Timer
var _arm_tween: Tween

const _CRACK_WIDEST_FRAME: int = 4
const _CRACK_BURST_FRAME: int = 5


## Which lane the i-th enemy out of the door takes. Static and pure so it can be
## unit-tested headless.
static func lane_for_index(index: int, pattern: Array = []) -> int:
	if pattern.is_empty():
		var span: int = Lanes.FRONT_LANE - Lanes.BACK_LANE + 1
		return Lanes.clamp_lane(Lanes.BACK_LANE + (index % span))
	return Lanes.clamp_lane(int(pattern[index % pattern.size()]))


func _ready() -> void:
	crack.frame = 0
	dust.emitting = false
	_set_barriers(false)

	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = watchdog_seconds
	_watchdog.timeout.connect(_on_watchdog)
	add_child(_watchdog)

	trigger.body_entered.connect(_on_body_entered)
	Globals.player_death.connect(_on_player_death)


func _process(_delta: float) -> void:
	if not _active or _spawning:
		return
	_spawned = _spawned.filter(func(e): return is_instance_valid(e))
	if _spawned.is_empty():
		_end()


func _on_body_entered(body: Node2D) -> void:
	if _fired or body is not Player:
		return
	_fired = true
	player = body
	# body_entered fires inside a physics callback — defer the monitoring change.
	trigger.set_deferred("monitoring", false)
	_run()


func _run() -> void:
	# Telegraph: the crack widens and the wall rumbles before it gives.
	ScreenShake.apply_shake(3)
	_arm_tween = create_tween()
	_arm_tween.tween_property(crack, "frame", _CRACK_WIDEST_FRAME, arm_seconds)
	Globals.push_event()
	_pushed_event = true
	_active = true
	_spawning = true
	if lock_arena:
		_engage_lock()
	await get_tree().create_timer(arm_seconds).timeout
	if not is_inside_tree():
		return

	# Burst — the crack blows open into a hole and enemies pour out of it.
	# Kill the arm tween first: it targets frame 4 and its last step can otherwise
	# land after this assignment and stomp the burst frame back down.
	if _arm_tween != null and _arm_tween.is_valid():
		_arm_tween.kill()
	crack.frame = _CRACK_BURST_FRAME
	dust.emitting = true
	ScreenShake.apply_shake(9)
	if door_slam.stream != null:
		door_slam.play()
	_watchdog.start()

	for i in enemy_count:
		if not is_inside_tree() or not _active:
			_spawning = false
			return
		_spawn_one(i)
		await get_tree().create_timer(spawn_interval).timeout
	_spawning = false


func _spawn_one(index: int) -> void:
	var lane: int = lane_for_index(index, lane_pattern)
	var melee: bool = randf() < melee_ratio
	# Jitter X so melee maids (which collide with each other) don't pile up in the
	# doorway; combined with the spawn stagger this reads as "pouring out".
	var x: float = door_mouth.global_position.x + randf_range(-12.0, 12.0)
	var enemy := EnemySpawner.spawn_enemy_at(
		get_tree().current_scene, player, x, lane, melee)
	if enemy != null:
		enemy.lane_change_cooldown = randf_range(lane_hold_min, lane_hold_max)
		_spawned.append(enemy)


func _engage_lock() -> void:
	# Keep the walls in sync with the exported arena width rather than the authored
	# scene positions, so tuning arena_half_width moves both together.
	left_wall.get_parent().position.x = -arena_half_width
	right_wall.get_parent().position.x = arena_half_width
	_set_barriers(true)
	var cam: Camera2D = player.camera_2d
	if cam == null:
		return
	_saved_limit_left = cam.limit_left
	_saved_limit_right = cam.limit_right
	var centre: int = int(door_mouth.global_position.x)
	cam.limit_left = centre - arena_half_width
	cam.limit_right = centre + arena_half_width


func _release_lock() -> void:
	_set_barriers(false)
	var cam: Camera2D = player.camera_2d if player != null else null
	if cam == null:
		return
	cam.limit_left = _saved_limit_left
	cam.limit_right = _saved_limit_right


func _set_barriers(enabled: bool) -> void:
	left_wall.set_deferred("disabled", not enabled)
	right_wall.set_deferred("disabled", not enabled)


func _on_watchdog() -> void:
	# Release the player but leave any stragglers alive — fairer than purging them.
	if _active:
		_end()


func _on_player_death() -> void:
	# Never let a restart inherit a locked camera or raised barriers.
	if _active:
		_end()


func _end() -> void:
	if not _active:
		return
	_active = false
	_watchdog.stop()
	if _arm_tween != null and _arm_tween.is_valid():
		_arm_tween.kill()
	if lock_arena:
		_release_lock()
	if _pushed_event:
		Globals.pop_event()
		_pushed_event = false
	encounter_finished.emit()
	if one_shot:
		queue_free()
