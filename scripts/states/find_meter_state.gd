extends EnemyState
class_name FindMeterState

## Out of coins — walk to the nearest parking meter and top up.

## Beyond this the meter isn't worth the trip; the maid tops up off-screen instead.
const GIVE_UP_DISTANCE := 200.0
## Close enough to reach the coin slot.
const REFILL_DISTANCE := 30.0
const REFILL_SECONDS := 2.0
const COINS_FROM_METER := 4
## Consolation refill when there's no reachable meter, so she rejoins the fight.
const COINS_WHEN_UNREACHABLE := 2

var dir: Vector2
var meter: Meter
var stand_still: bool = false
## Bumped on entry/exit so the refill wait can tell whether it is still the
## current visit. The state object outlives any one visit, so an await left over
## from a previous trip used to resume later and yank the maid out of whatever she
## was doing (mid-swing, most visibly) and back into a chase.
var _generation: int = 0


func enter_state() -> void:
	_generation += 1
	stand_still = false
	meter = Globals.nearest_meter(enemy.global_position)
	if meter == null:
		# No meters registered at all (boss room, an arena encounter, a test scene).
		# Dead-ending in a state with no target is what left maids standing around.
		_resume_combat(COINS_WHEN_UNREACHABLE)
		return
	# Meters live on the walkway — step back to the ground lane before seeking one.
	if enemy.lane != Lanes.GROUND_LANE:
		enemy._start_lane_change(Lanes.GROUND_LANE)
	if enemy.global_position.distance_to(meter.global_position) >= GIVE_UP_DISTANCE:
		_resume_combat(COINS_WHEN_UNREACHABLE)
		return
	enemy.animated_sprite_2d.play("walk")


func exit_state() -> void:
	_generation += 1
	stand_still = false
	enemy.coin_audio_player.stop()


func update(delta: float) -> void:
	if enemy.is_changing_lane:
		return
	if stand_still:
		enemy.velocity.x = 0
		# Don't pause the "refill" animation itself — it was just started this same
		# entry into stand_still and pausing it here freezes it on frame 0 for the
		# whole wait, so the maid never visibly reaches for the meter.
		if enemy.animated_sprite_2d.animation != "refill":
			enemy.animated_sprite_2d.pause()
		return

	if not is_instance_valid(meter):
		_resume_combat(COINS_WHEN_UNREACHABLE)
		return

	var dist: float = enemy.global_position.distance_to(meter.global_position)
	dir = (meter.global_position - enemy.global_position).normalized()

	enemy.face_towards(meter.global_position.x)
	if dist < REFILL_DISTANCE and enemy.coins <= 0:
		_refill_at_meter()
	elif dist >= GIVE_UP_DISTANCE and not enemy.is_meter_in_line_of_sight():
		_resume_combat(COINS_WHEN_UNREACHABLE)
	else:
		enemy.move_towards_target(meter.global_position, delta)


func _refill_at_meter() -> void:
	var gen := _generation
	stand_still = true
	enemy.coins += COINS_FROM_METER
	meter.play_animation()
	enemy.velocity.x = 0
	enemy.coin_audio_player.play()
	# The refill art is authored facing right like walk/idle, so the body flip that
	# carried us here already points the reaching hand at the meter. (An earlier
	# flip_h = true here was compensating for the walk-to-meter facing being
	# inverted; with that fixed it would mirror the maid back away from the meter.)
	enemy.face_towards(meter.global_position.x)
	enemy.animated_sprite_2d.play("refill", 2)
	Utils.shake_two_node2d(enemy.animated_sprite_2d, meter, 3)
	await enemy.get_tree().create_timer(REFILL_SECONDS).timeout
	if gen != _generation or not is_instance_valid(enemy):
		return
	_resume_combat(0)


## Leave for the best available fighting state. Not every enemy that can run out
## of coins is guaranteed to have a chase state, so fall through the options.
func _resume_combat(bonus_coins: int) -> void:
	enemy.coins += bonus_coins
	for state_name in ["ChasePlayerState", "PatrolState", "PlatformPatrolState", "HoldPositionState"]:
		if enemy.has_state(state_name):
			enemy.enemy_state_machine.change_state(state_name)
			return
