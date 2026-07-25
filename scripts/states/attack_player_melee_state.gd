extends AttackPlayerState
class_name AttackPlayerMeleeState

## Close-range swing: an Area2D overlap test instead of a thrown coin.
##
## Everything else (generation guard, release-frame clamping, watchdog, exits)
## comes from AttackPlayerState — this only re-points the clip and the hit.


func _init(e: Enemy) -> void:
	super._init(e)
	clip = "melee"
	telegraph_frame = 3
	# The base metermaid sprite set's "melee" clip is 7 frames and the melee set's
	# is 8, so the old hardcoded `frame == 7` end-of-swing check silently never
	# fired on the shorter one. The base class clamps this to the real clip length
	# and closes the swing on animation_finished instead of a magic frame index.
	release_frame_hint = 6


func _do_hit() -> void:
	if not enemy.is_same_lane_as_player():
		return
	for body in enemy.attack_area.get_overlapping_bodies():
		if body is Player:
			body.receive_hit(enemy.global_position, 1)


func _telegraph(gen: int) -> void:
	Utils.shake_node2d(enemy, 2, 0.2)
	await enemy.get_tree().create_timer(0.2).timeout
	if gen != _generation or not is_instance_valid(enemy):
		return
	enemy.attack_player.play()
