extends EnemyState
class_name ChasePlayerState

## Focused state that only handles chasing the player (movement logic)

func enter_state() -> void:
	enemy.animated_sprite_2d.play("walk")
	enemy.line_of_sight.enabled = true
	
func exit_state() -> void:
	enemy.line_of_sight.enabled = false

func update(delta: float) -> void:
	if enemy.has_state("AttackPlayerState") and (enemy.can_attack() and enemy.is_player_in_line_of_sight()):
		enemy.enemy_state_machine.change_state("AttackPlayerState")	
		return
		
	if enemy.has_state("BossAttackPlayerState") and (enemy.can_attack() and enemy.is_player_in_line_of_sight()):
		enemy.enemy_state_machine.change_state("BossAttackPlayerState")	
		return
		
	if enemy.has_state("PatrolState") and (not enemy.can_see_player_threshold(1.2) or not enemy.is_player_in_line_of_sight()):
		enemy.enemy_state_machine.change_state("PatrolState")
		return
			
	# Always work toward the player's own lane — combat only connects same-lane
	# (a previous version diverted extra attackers to adjacent lanes, which left
	# them permanently unable to attack; turn-taking slots now do that job).
	if not enemy.is_same_lane_as_player():
		enemy._lane_chase()

	# Handle animation and movement (but don't override knockback). Movement always
	# targets a standoff distance (_chase_toward_player), not the player's exact
	# center, so nothing walks the enemy on top of the player. Only chase while
	# the player is actually seen (matches the old approach-branch gating) and
	# not near a ground-lane edge.
	var has_los: bool = enemy.is_player_in_line_of_sight()
	var not_knocked_back: bool = abs(enemy.knockback_velocity.x) < 10.0
	var can_move: bool = not_knocked_back and has_los and not enemy.is_near_edge()
	if can_move:
		enemy._chase_toward_player(delta)
	elif not_knocked_back:
		enemy.velocity.x = 0

	# is_holding_position (standoff-based) rather than is_the_player_in_attack_range()
	# (Area2D-based) — a queued enemy's wait_standoff can sit outside that circle for
	# tightly-ranged enemies, and it should still read as idle/waiting, not walking.
	if not enemy.is_holding_position and has_los and not enemy.is_near_edge():
		enemy.animated_sprite_2d.play("walk")
	else:
		enemy._face_player()
		enemy.animated_sprite_2d.play("idle")
