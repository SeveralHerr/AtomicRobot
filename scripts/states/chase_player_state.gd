extends EnemyState
class_name ChasePlayerState

## Walk-toward-the-player state. Hands off to the attack state once the player is
## in reach, in the same lane (or we're a lane-locked shooter) and actually visible.

## How far past `detection_range` an enemy keeps closing before giving up. Chase
## movement uses distance, not the sight ray — see update().
const PURSUE_SLACK := 1.5


func enter_state() -> void:
	enemy.animated_sprite_2d.play("walk")
	enemy.line_of_sight.enabled = true

func exit_state() -> void:
	enemy.line_of_sight.enabled = false

func update(delta: float) -> void:
	if enemy._resolve_player() == null:
		enemy.velocity.x = 0
		return

	var sees_player: bool = enemy.is_player_in_line_of_sight()

	# Landing a hit still requires a clear line — you can't be shot through a wall.
	if enemy.has_state("AttackPlayerState") and enemy.can_attack() and sees_player:
		enemy.enemy_state_machine.change_state("AttackPlayerState")
		return

	if enemy.has_state("BossAttackPlayerState") and enemy.can_attack() and sees_player:
		enemy.enemy_state_machine.change_state("BossAttackPlayerState")
		return

	if enemy.has_state("PatrolState") and (not enemy.can_see_player_threshold(1.2) or not sees_player):
		enemy.enemy_state_machine.change_state("PatrolState")
		return

	var target_x: float = enemy.player.global_position.x
	var travel_dir: int = signi(target_x - enemy.global_position.x)

	# Approaching is gated on DISTANCE, not on the sight ray. The ray reports only
	# the first collider on one straight line, so clipping a lamppost — or simply
	# spawning a few px beyond its reach — used to zero the enemy's velocity, and
	# a MeterMaid has no PatrolState to fall back into, so it stood idle forever.
	# Enemies that lose sight now keep closing on your last position, which is
	# also the behaviour a beat-em-up wants.
	var in_pursuit: bool = sees_player or enemy.can_see_player_threshold(PURSUE_SLACK)

	if not enemy.is_the_player_in_attack_range() and in_pursuit:
		# Don't fight an active knockback — let it decay first.
		if absf(enemy.knockback_velocity.x) < 10.0:
			enemy._lane_chase()
			if enemy.is_near_edge_ahead(travel_dir):
				enemy.velocity.x = 0
			else:
				enemy.move_towards_target(enemy.player.global_position, delta)
		# Look where we are going. Nothing in the moving branch used to set facing
		# at all, so an enemy kept whatever direction it spawned with and moonwalked
		# the entire approach, only snapping around once it stopped to attack.
		enemy.face_towards(target_x)
		enemy.animated_sprite_2d.play("walk")
	else:
		if not enemy.is_same_lane_as_player():
			enemy._lane_chase()
		enemy._face_player()
		enemy.animated_sprite_2d.play("idle")
		if absf(enemy.knockback_velocity.x) < 10.0:
			enemy.velocity.x = 0
