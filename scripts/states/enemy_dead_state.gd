extends EnemyState
class_name DeadEnemyState

func enter_state(enemy: Enemy) -> void:
	enemy.velocity = Vector2.ZERO
	Globals.meter_maids_killed += 1
	Globals.meter_maid_death.emit()
	enemy.animated_sprite_2d.play("death")
	await enemy.get_tree().create_timer(1.5).timeout
	enemy.hide()
	enemy.queue_free()	
