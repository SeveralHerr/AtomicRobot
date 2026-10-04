extends EnemyState
class_name BossDashState

## Phase-3 charge: the boss plants, shakes and flushes red (the tell), then barrels
## across the room through the player's spot. Jump over him or get flattened.
## Ends at the far side, a wall, or a timeout, and hands back to the throw state.

const TELL := 0.6
const SPEED := 640.0
## How far past the player he runs before stopping.
const OVERSHOOT := 220.0
const MAX_RUN := 1.6
## Contact box: horizontal reach, and how far above his feet a player's feet must be
## to clear him (a jump clears it; standing or crouching does not).
const HIT_REACH := 34.0
const CLEAR_HEIGHT := 40.0

var _t: float = 0.0
var _dir: int = 1
var _target_x: float = 0.0
var _hit: bool = false


func enter_state() -> void:
	_t = 0.0
	_hit = false
	enemy.velocity.x = 0.0
	enemy._face_player()
	_dir = enemy.facing
	var px: float = enemy.player.global_position.x if enemy.player else enemy.global_position.x
	_target_x = px + _dir * OVERSHOOT
	enemy.animated_sprite_2d.play("idle")
	Utils.shake_node2d(enemy, 3.0, TELL)
	var tw := enemy.create_tween()
	tw.tween_property(enemy.animated_sprite_2d, "self_modulate", Color(1.6, 0.5, 0.5), TELL * 0.5)
	tw.tween_property(enemy.animated_sprite_2d, "self_modulate", Color.WHITE, TELL * 0.5)


func exit_state() -> void:
	enemy.velocity.x = 0.0
	enemy.animated_sprite_2d.self_modulate = Color.WHITE


func update(delta: float) -> void:
	_t += delta
	if _t < TELL:
		enemy.velocity.x = 0.0
		return
	if enemy.animated_sprite_2d.animation != "dash":
		enemy.animated_sprite_2d.play("dash")
	enemy.velocity.x = _dir * SPEED
	_try_hit()
	var arrived := (enemy.global_position.x - _target_x) * _dir >= 0.0
	if arrived or enemy.is_on_wall() or _t > TELL + MAX_RUN:
		enemy.enemy_state_machine.change_state("BossAttackPlayerState")


func _try_hit() -> void:
	var p: Player = enemy.player
	if _hit or p == null or p.is_dead:
		return
	if contact(enemy.global_position.x, enemy.global_position.y + enemy.foot_offset(),
			p.global_position.x, p.global_position.y + p.foot_offset()):
		_hit = true
		p.receive_hit(enemy.global_position, 1, 520.0)
		ScreenShake.apply_shake(10.0, 0.5)


## Whether a charging boss with feet at (bx, by) flattens a player with feet at
## (px, py). Pure for the unit test.
static func contact(bx: float, by: float, px: float, py: float) -> bool:
	return absf(px - bx) < HIT_REACH and (by - py) < CLEAR_HEIGHT
