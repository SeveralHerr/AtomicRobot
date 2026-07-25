extends AttackPlayerState
class_name BossAttackPlayerState

## The final boss's briefcase throw. Same swing machinery as the maids, but the
## boss never disengages: it has no chase or patrol state, so it re-arms in place
## on a fixed beat rather than waiting for a cooldown/range check to line up.

## Beat between briefcases. Preserves the boss's original cadence, which came from
## a hardcoded `await 0.5` followed by an unconditional re-entry.
const BOSS_RE_ARM_DELAY := 0.5


func _init(e: Enemy) -> void:
	super._init(e)
	release_frame_hint = 4
	telegraph_frame = -1  # no wind-up shake
	re_arm_delay = BOSS_RE_ARM_DELAY


func _do_hit() -> void:
	is_player_crouched = _player_is_crouched()
	Utils.throw_briefcase_from_enemy(enemy, false, 10 if is_player_crouched else 0)
	enemy.coins -= 1


## The boss keeps throwing regardless of range, lane or line of sight.
func _should_re_arm() -> bool:
	return true
