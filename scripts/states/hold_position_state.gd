extends EnemyState
class_name HoldPositionState

## Resting state for enemies that never move (window maids): stand, track the
## player, and swing again as soon as the cooldown lapses and there's a clear shot.
##
## Without this, a stationary attacker's only registered state was the attack
## itself, so it had nowhere to go when a swing finished — the old code papered
## over that by calling change_state("AttackPlayerState") from _physics_process
## every single frame, which re-entered the state (and restarted its animation)
## faster than the clip could reach its own release frame.


func enter_state() -> void:
	enemy.velocity.x = 0.0
	enemy.animated_sprite_2d.play("idle")


func update(_delta: float) -> void:
	enemy.velocity.x = 0.0
	enemy._face_player()
	if not enemy.has_state("AttackPlayerState"):
		return
	if enemy.can_attack() and enemy.is_player_in_line_of_sight():
		enemy.enemy_state_machine.change_state("AttackPlayerState")
