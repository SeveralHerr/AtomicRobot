extends EnemyState
class_name AttackPlayerState

## One attack swing, then hand off. Shared by the ranged maid (coin throw), the
## melee maid (AttackPlayerMeleeState) and the boss (BossAttackPlayerState);
## subclasses re-point the clip, the frame the hit lands on, and _do_hit().
##
## The old version drove itself with bare `await`s on a state object that lives as
## long as the enemy does. A swing interrupted before its awaits resolved left them
## pending, and they then resumed during the NEXT swing and flipped `attack_finished`
## true before the coin had left the hand — the enemy immediately transitioned out
## and, from the player's side, "randomly stopped attacking". Every deferred step
## here captures `_generation` and bails if it no longer matches.

## Fallback swing length. If the clip never reaches its release frame (interrupted,
## sprite set swapped for a shorter one) the swing is force-closed rather than
## parking in this state forever with `attack_finished` stuck false.
const ATTACK_TIMEOUT := 3.0

## Animation clip and its beats — overridden by subclasses in _init/_configure.
var clip: String = "attack"
var telegraph_frame: int = 4
## Preferred release frame; clamped to the clip's real length in _begin_swing so a
## shorter clip still connects instead of silently never firing.
var release_frame_hint: int = 6
## Seconds to hold after a swing before re-arming in place (stationary attackers).
var re_arm_delay: float = 0.0

var attack_finished: bool = false
var is_player_crouched: bool = false

var _generation: int = 0
var _release_frame: int = 6
var _released: bool = false
var _elapsed: float = 0.0
var _hold: float = 0.0


func enter_state() -> void:
	enemy.animated_sprite_2d.frame_changed.connect(_on_frame_changed)
	enemy.animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	_begin_swing()


func exit_state() -> void:
	# Invalidate any continuation still pending from this swing.
	_generation += 1
	enemy.animated_sprite_2d.frame_changed.disconnect(_on_frame_changed)
	enemy.animated_sprite_2d.animation_finished.disconnect(_on_animation_finished)


func _begin_swing() -> void:
	_generation += 1
	attack_finished = false
	_released = false
	_elapsed = 0.0
	_hold = 0.0
	enemy.velocity.x = 0
	enemy._face_player()
	is_player_crouched = _player_is_crouched()

	var spr: AnimatedSprite2D = enemy.animated_sprite_2d
	var frame_count: int = spr.sprite_frames.get_frame_count(clip) if spr.sprite_frames else 0
	_release_frame = release_frame_for(release_frame_hint, frame_count)
	# play() does not rewind a clip that is already selected, so a re-arm would
	# resume from the last frame and never cross the release frame again.
	spr.set_frame_and_progress(0, 0.0)
	spr.play(clip)


## The frame a swing actually connects on, given the clip's real length.
##
## Clamping matters: the two shipped maid sprite sets disagree about clip length
## ("melee" is 7 frames in metermaid_sprite_frames and 8 in the melee set), and the
## old code compared `frame == 7` against whichever was loaded — on the shorter clip
## that comparison could never be true, so the swing never closed out and the maid
## stood frozen in her attack state. Pure and static so it can be unit-tested.
static func release_frame_for(hint: int, frame_count: int) -> int:
	return clampi(hint, 0, maxi(frame_count - 1, 0))


func _player_is_crouched() -> bool:
	var p: Player = enemy.player
	if p == null or p.state_machine == null:
		return false
	return p.state_machine.current_state is CrouchState


func _on_frame_changed() -> void:
	var spr: AnimatedSprite2D = enemy.animated_sprite_2d
	if spr.animation != clip:
		return
	if spr.frame == _release_frame and not _released:
		_release()
	elif spr.frame == telegraph_frame:
		_telegraph(_generation)


func _on_animation_finished() -> void:
	if enemy.animated_sprite_2d.animation != clip:
		return
	if not _released:
		# The clip ended without crossing its release frame — connect anyway so a
		# short or retimed clip can't quietly swallow the attack.
		_release()
	_finish_swing()


func _release() -> void:
	_released = true
	enemy._face_player()
	_do_hit()
	enemy.attack_timer.start()


func _finish_swing() -> void:
	if enemy.enemy_state_machine.current_state is not DeadEnemyState:
		enemy.animated_sprite_2d.play("idle")
	attack_finished = true


## The actual damage/projectile. Subclasses override.
func _do_hit() -> void:
	Utils.throw_coin_from_enemy(enemy, false, 10 if is_player_crouched else 0)
	enemy.coins -= 1


## Wind-up flourish. `gen` is the swing this was scheduled for.
func _telegraph(gen: int) -> void:
	await enemy.get_tree().create_timer(0.2).timeout
	if gen != _generation or not is_instance_valid(enemy):
		return
	Utils.shake_node2d(enemy, 2, 0.2)


## Whether a stationary attacker (no chase/patrol/hold state) should swing again.
func _should_re_arm() -> bool:
	return enemy.can_attack() and enemy.is_player_in_line_of_sight()


func update(delta: float) -> void:
	enemy._face_player()

	if not attack_finished:
		_elapsed += delta
		if _elapsed < ATTACK_TIMEOUT:
			return
		# Watchdog: close the swing out so the exits below can run.
		if not _released:
			_release()
		_finish_swing()

	if enemy.has_state("PlatformPatrolState"):
		enemy.enemy_state_machine.change_state("PlatformPatrolState")
		return

	if enemy.has_state("FindMeterState") and enemy.coins <= 0:
		enemy.enemy_state_machine.change_state("FindMeterState")
		return

	# Unconditional, unlike the old `and not enemy.can_attack()`. When the cooldown
	# had already lapsed by the time the clip ended, that guard fell through every
	# branch and left the enemy parked here doing nothing — the state machine now
	# also refuses same-state re-entry, so there was no way back out. Chase
	# re-evaluates range, lane and sight next tick and comes straight back if the
	# shot is still on.
	if enemy.has_state("ChasePlayerState"):
		enemy.enemy_state_machine.change_state("ChasePlayerState")
		return

	if enemy.has_state("HoldPositionState"):
		enemy.enemy_state_machine.change_state("HoldPositionState")
		return

	# Nothing to fall back to (a stationary attacker): re-arm in place.
	_hold += delta
	if _hold >= re_arm_delay and _should_re_arm():
		_begin_swing()
