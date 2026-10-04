extends Node
class_name SandboxSelfTest

## Headless behaviour check for the enemy sandboxes.
##
## The unit runner (tools/run_tests.gd) runs one test at a time in a bare tree.
## Enemy AI is a multi-frame story across a whole scene, so the bugs that actually bite (an enemy that stops moving,
## a swing that never closes, a maid that walks backwards) are invisible to it.
## This node runs inside a real scene with real autoloads, samples every physics
## frame, and fails the process on anything that looks stuck.
##
## Attached automatically by EnemySandbox when `--sandbox-selftest` is passed:
##   godot --headless --path . res://test/scenes/mixed_cluster.tscn -- --sandbox-selftest

## Sampling window. Long enough for a maid to cross the arena, throw, run dry and
## reach a meter; short enough to run nine of them in a CI-ish loop.
const DURATION := 6.0
## Ignore the first moments: enemies are added deferred and need a frame or two to
## resolve the player, capture a lane baseline and settle onto their lane floor.
const WARMUP := 1.0
## An enemy that never moves this far and never reaches attack range is inert.
const MIN_TRAVEL := 24.0
## Longest a single attack state may hold. AttackPlayerState.ATTACK_TIMEOUT is 3s,
## so anything past this means even the watchdog failed to close the swing.
const MAX_ATTACK_DWELL := 4.0
## Facing is only meaningful outside the deadzone Enemy.face_towards() respects.
const FACING_MIN_DX := 8.0

var sandbox: EnemySandbox

var _elapsed: float = 0.0
var _tracks: Dictionary = {}
var _failures: PackedStringArray = []
var _coins_thrown: int = 0
var _saw_attack_state: bool = false
var _done: bool = false
## Times the player lost health. Health starts at 9999, so it never ends the run.
var _player_hits: int = 0
var _last_player_health: int = -1
## Lane steps the COIN_LANE_DODGE scenario made in answer to a wind-up.
var _dodges: int = 0
## Lowest a dodged coin flew (px above its lane floor) as it passed the player.
## A coin aimed at the player's NEW lane dives to the floor and skids past.
var _min_pass_height: float = INF
## Swings that began with the player grounded right on top of the maid.
var _point_blank_swings: int = 0


class Track:
	var min_x: float = INF
	var max_x: float = -INF
	var start_distance: float = INF
	var last_distance: float = INF
	var attack_dwell: float = 0.0
	var coins_seen: int = -1
	var coins_spent: int = 0
	var reached_range: bool = false
	var was_attacking: bool = false
	var facing_errors: int = 0
	var facing_samples: int = 0
	var label: String = "?"
	## False for enemies with no locomotion state at all (window maids) — they are
	## supposed to stand still, so the inert-enemy check must not fire on them.
	var mobile: bool = true


func _ready() -> void:
	# Nothing here should be able to end the run early or skew the sample.
	if sandbox != null and sandbox.player != null:
		sandbox.player.health = 9999


func _physics_process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed < WARMUP:
		return
	_sample(delta)
	if _elapsed >= WARMUP + DURATION:
		_done = true
		_report()


func _sample(delta: float) -> void:
	var player: Player = sandbox.player if sandbox != null else null
	if player == null:
		return
	if _last_player_health >= 0 and player.health < _last_player_health:
		_player_hits += 1
	_last_player_health = player.health
	_pin_player_on_maid(player)
	_sample_coin_flight(player)
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node is not Enemy:
			continue
		var e: Enemy = node
		var id := e.get_instance_id()
		var t: Track = _tracks.get(id)
		if t == null:
			t = Track.new()
			t.label = "%s@%d" % [e.get_script().resource_path.get_file().trim_suffix(".gd"), id % 10000]
			t.start_distance = e.global_position.distance_to(player.global_position)
			t.coins_seen = e.coins
			for locomotion in ["ChasePlayerState", "PatrolState", "PlatformPatrolState"]:
				t.mobile = e.has_state(locomotion)
				if t.mobile:
					break
			_tracks[id] = t

		t.min_x = minf(t.min_x, e.global_position.x)
		t.max_x = maxf(t.max_x, e.global_position.x)
		t.last_distance = e.global_position.distance_to(player.global_position)
		if e.is_player_in_attack_range:
			t.reached_range = true
		if e.coins < t.coins_seen:
			var spent: int = t.coins_seen - e.coins
			t.coins_spent += spent
			_coins_thrown += spent
		t.coins_seen = e.coins

		var state = e.enemy_state_machine.current_state
		if state is AttackPlayerState:
			_saw_attack_state = true
			t.attack_dwell += delta
			if not t.was_attacking:
				_on_wind_up(player)
				if _elapsed > WARMUP + 0.5 and absf(player.global_position.x - e.global_position.x) < 10.0:
					_point_blank_swings += 1
		else:
			t.attack_dwell = 0.0
		t.was_attacking = state is AttackPlayerState

		# Walking the wrong way round is the single most visible AI bug in this
		# game and it survived for a long time, so it gets sampled every frame.
		if state is ChasePlayerState:
			var dx: float = player.global_position.x - e.global_position.x
			if absf(dx) > FACING_MIN_DX and absf(e.velocity.x) > 5.0:
				t.facing_samples += 1
				if signi(dx) != e.facing:
					t.facing_errors += 1


## Point-blank scenarios keep the player standing exactly on the maid: knockback
## from her first hit would otherwise slide them apart and hide a stall.
func _pin_player_on_maid(player: Player) -> void:
	if sandbox.scenario != EnemySandbox.Scenario.POINT_BLANK_RANGED 			and sandbox.scenario != EnemySandbox.Scenario.POINT_BLANK_MELEE:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and not node.is_dead:
			player.global_position.x = node.global_position.x
			player.velocity.x = 0.0
			return


func _sample_coin_flight(player: Player) -> void:
	if sandbox.scenario != EnemySandbox.Scenario.COIN_LANE_DODGE or not is_finite(player.lane_floor_y):
		return
	# Coins go next to the player, which Lanes re-parents under its sort layer.
	for c in player.get_parent().get_children():
		var coin := c as Bullet
		if coin == null or coin.has_landed or absf(coin.global_position.x - player.global_position.x) > 30.0:
			continue
		var h := Lanes.floor_y(player.lane_floor_y, coin.lane) - coin.global_position.y
		_min_pass_height = minf(_min_pass_height, h)


## A swing just started. In the dodge scenario the player answers it the way a
## person would: one lane step, away from the wall of the road.
func _on_wind_up(player: Player) -> void:
	if sandbox.scenario != EnemySandbox.Scenario.COIN_LANE_DODGE:
		return
	var dir := 1 if player.current_lane < Lanes.FRONT_LANE else -1
	if player.try_change_lane(dir):
		_dodges += 1


func _fail(msg: String) -> void:
	_failures.append(msg)


func _report() -> void:
	var scenario_name: String = sandbox.name if sandbox != null else "?"

	if _tracks.is_empty():
		_fail("no enemies were ever sampled — the scenario built nothing")

	for id in _tracks:
		var t: Track = _tracks[id]
		var travelled: float = t.max_x - t.min_x if t.max_x > t.min_x else 0.0

		# 1. Inert enemies. The LoS-gated chase used to freeze maids at spawn
		#    distance (~477px) because the sight ray only reached 450. Enemies
		#    that own no locomotion state (window maids) are stationary by design.
		if t.mobile and travelled < MIN_TRAVEL and not t.reached_range:
			_fail("%s never moved (%.1fpx) and never reached attack range (d=%.0f)"
				% [t.label, travelled, t.last_distance])

		# 2. A swing that never closes: the enemy parks in its attack state.
		if t.attack_dwell > MAX_ATTACK_DWELL:
			_fail("%s held an attack state for %.1fs (watchdog is %.1fs)"
				% [t.label, t.attack_dwell, AttackPlayerState.ATTACK_TIMEOUT])

		# 3. Moonwalking.
		if t.facing_samples > 10 and t.facing_errors > t.facing_samples / 4:
			_fail("%s faced away from the player while chasing in %d/%d samples"
				% [t.label, t.facing_errors, t.facing_samples])

	_scenario_checks()

	print("")
	print("=".repeat(64))
	print("  sandbox self-test: %s" % scenario_name)
	print("=".repeat(64))
	for id in _tracks:
		var t: Track = _tracks[id]
		print("  %-28s travel %6.1f  d %6.1f -> %6.1f  spent %d  facing %d/%d bad"
			% [t.label, t.max_x - t.min_x, t.start_distance, t.last_distance,
			   t.coins_spent, t.facing_errors, t.facing_samples])
	print("  min coin pass height: %.1f" % _min_pass_height)
	print("  enemies sampled: %d   projectiles thrown: %d   player hits: %d   dodges: %d"
		% [_tracks.size(), _coins_thrown, _player_hits, _dodges])
	if _failures.is_empty():
		print("  RESULT: PASS")
		print("")
		get_tree().quit(0)
		return
	for f in _failures:
		print("  FAIL: %s" % f)
	print("  RESULT: FAIL (%d)" % _failures.size())
	print("")
	get_tree().quit(1)


## Expectations that only make sense for a particular sandbox.
func _scenario_checks() -> void:
	if sandbox == null:
		return
	match sandbox.scenario:
		EnemySandbox.Scenario.RANGED_CLUSTER, EnemySandbox.Scenario.MIXED_CLUSTER:
			if not _saw_attack_state:
				_fail("no enemy ever entered an attack state")
			if _coins_thrown <= 0:
				_fail("ranged maids closed but never threw a coin")
			# Positive control for lane-bound coins: in-lane throws still connect.
			if _player_hits <= 0:
				_fail("no coin or swing ever hit a player standing still")

		EnemySandbox.Scenario.COIN_REFILL:
			# They start empty; reaching a meter is the whole scenario.
			var refilled := false
			for node in get_tree().get_nodes_in_group("enemies"):
				if node is Enemy and node.coins > 0:
					refilled = true
			if not refilled:
				_fail("every maid started empty and none topped up at a meter")

		EnemySandbox.Scenario.WINDOW_MAIDS:
			# Lane parity used to gate can_attack(), so a lane-locked maid went
			# silent the moment the player left the walkway; and with no hold state
			# to fall back to, one that did fire never re-armed.
			if _coins_thrown <= 0:
				_fail("window maids never threw a coin (lane gate or re-arm broken)")
			_check_window_maids_are_mortal()

		EnemySandbox.Scenario.COIN_LANE_DODGE:
			# A coin belongs to the lane it was thrown down. The old throw re-aimed at
			# the player's lane on the release frame, so a step during the wind-up
			# was tracked and the coin hit anyway.
			if _dodges <= 0 or _coins_thrown <= 0:
				_fail("no throw was dodged (dodges %d, coins %d) — scenario never engaged"
					% [_dodges, _coins_thrown])
			if _player_hits > 0:
				_fail("player was hit %d time(s) after stepping out of the thrower's lane"
					% _player_hits)
			# Flying down HER lane at chest height, not diving at the player's lane.
			if _min_pass_height < 12.0:
				_fail("coin passed the player only %.1fpx above its lane floor" % _min_pass_height)

		EnemySandbox.Scenario.POINT_BLANK_RANGED, EnemySandbox.Scenario.POINT_BLANK_MELEE:
			# Standing on a maid put her sight ray's origin inside the player's box,
			# so the ray never reported the player and she idled under you forever.
			if _point_blank_swings <= 0:
				_fail("maid under the player never attacked (point-blank sight lost)")
			if _player_hits <= 0:
				_fail("maid under the player never landed a hit")

		EnemySandbox.Scenario.NO_LINE_OF_SIGHT:
			# The point of the fix: sight is blocked, pursuit is not.
			var closed := false
			for id in _tracks:
				var t: Track = _tracks[id]
				if t.last_distance < t.start_distance - MIN_TRAVEL:
					closed = true
			if not closed:
				_fail("nothing closed on the player with line of sight blocked")


## Window maids had no DeadEnemyState registered, so Enemy.receive_hit()'s
## `has_state("DeadEnemyState")` guard never passed and they soaked unlimited
## damage. Hit one hard enough to kill it and check it actually dies.
func _check_window_maids_are_mortal() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is not MeterMaidWindow:
			continue
		var maid: Enemy = node
		if not maid.has_state("DeadEnemyState"):
			_fail("%s has no DeadEnemyState — it can never be killed" % maid.name)
			return
		maid.health = 1
		maid.receive_hit(5)
		return
