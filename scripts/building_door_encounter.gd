extends Node2D
class_name BuildingDoorEncounter

## TMNT-style "enemies burst out of a building" encounter.
##
## Walk into the trigger, the door bursts open, a squad pours out and fans across
## the lanes, and — if `lock_arena` — barriers plus camera limits hold the player
## there until the street is clear. The squad comes out in 1–3 `waves`: each one
## rumbles the door and bursts it again once the previous wave is down, with a
## comic "WAVE 2/3" callout (EncounterAnnouncer), then "STREET CLEAR!" at the end.
##
## `DoorMouth/Crack` (sprites/crack.png) doubles as the visual: a hairline crack
## sits at the base of the wall as a permanent tell for where an encounter lives,
## widens through the telegraph, and blows open into a hole enemies pour out of.

## Lock released — cleared, watchdog, or player death.
signal encounter_finished
## A wave starts its telegraph. `index` is 1-based, of `total`.
signal wave_started(index: int, total: int)
## The last wave went down (not emitted for a watchdog or death release).
signal street_cleared

## Whole squad across all waves.
@export var enemy_count: int = 4
## How many waves the squad comes out in. The next wave waits for the current one
## to be fully down (not "nearly"): the player never fights two waves at once, so
## total pressure stays close to the old one-burst squad, and every callout lands
## over an empty street where it can be read. See wave_sizes() for the split.
@export_range(1, 3) var waves: int = 1
## Breather between a wave's last kill and the next wave's rumble.
@export var wave_gap_seconds: float = 0.8
## Door rumble before every wave after the first (the first uses arm_seconds,
## because the crack-widening telegraph already ran while the player walked up).
## Long enough for the "WAVE n/N" banner to land before anyone steps out.
@export var rearm_seconds: float = 0.7
## Fraction of the squad that spawns as melee maids. Ranged maids run FindMeterState
## when they run dry, which walks them into a barrier if no meter is inside the
## arena — so keep this high unless the encounter is placed near parking meters.
@export_range(0.0, 1.0) var melee_ratio: float = 0.75
@export var spawn_interval: float = 0.15
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
## How long a spawned enemy takes to step from the crack out to its fan-out lane.
## Deliberately much slower than Enemy.LANE_CHANGE_DURATION (0.2s, tuned for snappy
## in-combat repositioning) — this is a "walking out of the doorway" beat, not a
## combat dodge, so it should read as a walk, not a snap. 0.6s: at 1.0s the
## whole squad took ~2s to fill the lanes, long enough to read as sluggish.
@export var walk_out_seconds: float = 0.6
## Extra beat after the walk-out before a spawned enemy may attack. Its total
## no-attack window is walk_out_seconds + this (Enemy.spawn_grace), so the squad
## lands in its lanes before anyone swings instead of swarming the doorway.
## Only the spawned enemies are held — the game itself never pauses.
@export var settle_seconds: float = 0.3
## Move speed multiplier applied to a freshly-spawned enemy for walk_out_seconds,
## so it doesn't immediately sprint at full chase speed the instant it appears.
@export_range(0.05, 1.0) var walk_out_speed_scale: float = 0.4
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
var _plan: Array = []
var _wave: int = 0
var _spawn_index: int = 0
var _announcer: EncounterAnnouncer

const _CRACK_WIDEST_FRAME: int = 4
const _CRACK_BURST_FRAME: int = 5


## Which lane the i-th enemy out of the door takes. Static and pure so it can be
## unit-tested headless.
static func lane_for_index(index: int, pattern: Array = []) -> int:
	if pattern.is_empty():
		var span: int = Lanes.FRONT_LANE - Lanes.BACK_LANE + 1
		return Lanes.clamp_lane(Lanes.BACK_LANE + (index % span))
	return Lanes.clamp_lane(int(pattern[index % pattern.size()]))


## Splits `total` enemies into `wave_count` waves (clamped to 1–3 and to `total`),
## remainder back-loaded so the last wave is the biggest: 5 over 2 -> [2, 3].
static func wave_sizes(total: int, wave_count: int) -> Array:
	var n: int = mini(clampi(wave_count, 1, 3), maxi(total, 1))
	var sizes: Array = []
	for i in n:
		sizes.append(total / n + (1 if i >= n - total % n else 0))
	return sizes


## How long a freshly-spawned enemy is barred from attacking: walk out, then settle.
func attack_grace_seconds() -> float:
	return walk_out_seconds + settle_seconds


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
	# Dropped on death, not on free: a corpse plays out ~3.5s of death clip and
	# blink-out before queue_free, and holding the arena lock for that long reads
	# as the encounter having hung after the last kill. See Enemy.is_dead.
	_spawned = _spawned.filter(_is_alive)
	if not _spawned.is_empty():
		return
	if _wave < _plan.size() - 1:
		_next_wave()
	else:
		street_cleared.emit()
		_end()


func _is_alive(enemy: Node2D) -> bool:
	if not is_instance_valid(enemy):
		return false
	return not (enemy is Enemy and enemy.is_dead)


func _on_body_entered(body: Node2D) -> void:
	if _fired or body is not Player:
		return
	_fired = true
	player = body
	# body_entered fires inside a physics callback — defer the monitoring change.
	trigger.set_deferred("monitoring", false)
	_run()


func _run() -> void:
	_plan = wave_sizes(enemy_count, waves)
	_announcer = EncounterAnnouncer.new()
	add_child(_announcer)
	_announcer.watch(self)
	Globals.push_event()
	_pushed_event = true
	_active = true
	if lock_arena:
		_engage_lock()
	_play_wave(0)


func _next_wave() -> void:
	# _spawning holds off _process's completion check through the breather.
	_spawning = true
	_watchdog.start(watchdog_seconds)
	await get_tree().create_timer(wave_gap_seconds).timeout
	if _live():
		_play_wave(_wave + 1)


## Telegraph, burst, then file wave `index` out of the door. The watchdog restarts
## per wave, so a long encounter is never cut short and a stuck one always frees.
func _play_wave(index: int) -> void:
	_wave = index
	_spawning = true
	_watchdog.start(watchdog_seconds)
	wave_started.emit(index + 1, _plan.size())
	await _telegraph(index == 0)
	if not _live():
		return
	_burst()
	for i in _plan[index]:
		if not _live():
			_spawning = false
			return
		_spawn_one(_spawn_index)
		_spawn_index += 1
		await get_tree().create_timer(spawn_interval).timeout
	_spawning = false


func _live() -> bool:
	return is_inside_tree() and _active


## First wave: the crack widens. Later waves: the blown-open hole rattles.
func _telegraph(first: bool) -> void:
	ScreenShake.apply_shake(3)
	_arm_tween = create_tween()
	var wait: float = arm_seconds
	if first:
		_arm_tween.tween_property(crack, "frame", _CRACK_WIDEST_FRAME, arm_seconds)
	else:
		wait = rearm_seconds
		var beat: float = rearm_seconds / 6.0
		_arm_tween.set_loops(3)
		_arm_tween.tween_property(crack, "scale", Vector2(1.25, 1.15), beat)
		_arm_tween.tween_property(crack, "scale", Vector2.ONE, beat)
	await get_tree().create_timer(wait).timeout


## The crack blows open into a hole and enemies pour out of it.
func _burst() -> void:
	# Kill the arm tween first: it targets frame 4 and its last step can otherwise
	# land after this assignment and stomp the burst frame back down.
	if _arm_tween != null and _arm_tween.is_valid():
		_arm_tween.kill()
	crack.frame = _CRACK_BURST_FRAME
	crack.scale = Vector2.ONE
	dust.restart()
	ScreenShake.apply_shake(9)
	if door_slam.stream != null:
		door_slam.play()


func _spawn_one(index: int) -> void:
	var target_lane: int = lane_for_index(index, lane_pattern)
	var melee: bool = randf() < melee_ratio
	# Small jitter so melee maids (which collide with each other) don't spawn
	# perfectly stacked; combined with the spawn stagger and the walk-out below,
	# this reads as a squad individually filing out of the doorway.
	var x: float = door_mouth.global_position.x + randf_range(-8.0, 8.0)
	# Everyone spawns at the crack itself (ground lane, on the wall) — _walk_out()
	# below is what actually sends each one out to its fan-out lane, so they're
	# seen leaving the doorway instead of just appearing already in position.
	var enemy := EnemySpawner.spawn_enemy_at(
		get_tree().current_scene, player, x, Lanes.GROUND_LANE, melee)
	if enemy == null:
		return
	# Block the AI's own eager lane-chase (Enemy._lane_chase, polled every frame by
	# ChasePlayerState) until the walk-out step below has run — its cooldown starts
	# at 0.0, so left alone it fires on the very first physics tick and steps the
	# maid toward the PLAYER's lane instead of its assigned fan-out lane.
	enemy.lane_change_cooldown = arm_seconds + 1.0
	enemy.spawn_grace = attack_grace_seconds()
	_spawned.append(enemy)
	_walk_out(enemy, target_lane)


## Steps a freshly-spawned enemy from the crack out to its fan-out lane, so it
## visibly leaves the doorway rather than appearing already in position.
## Deferred one frame: spawn_enemy_at()'s add_child is deferred, so the node isn't
## in the tree yet when _spawn_one() returns — create_tween() needs it to be.
func _walk_out(enemy: Enemy, target_lane: int) -> void:
	await get_tree().process_frame
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var normal_speed: float = enemy.move_speed
	enemy.move_speed = normal_speed * walk_out_speed_scale
	if target_lane != Lanes.GROUND_LANE:
		enemy._start_lane_change(target_lane, walk_out_seconds)
	enemy.lane_change_cooldown = randf_range(lane_hold_min, lane_hold_max)
	await get_tree().create_timer(walk_out_seconds).timeout
	if is_instance_valid(enemy):
		enemy.move_speed = normal_speed


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
		# Outlive the STREET CLEAR! callout, which lives under this node.
		get_tree().create_timer(2.0).timeout.connect(queue_free)
