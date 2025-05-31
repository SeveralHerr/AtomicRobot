extends EnemyState
class_name DeadEnemyState

func enter_state(enemy: Enemy) -> void:
	enemy.velocity = Vector2.ZERO
	Globals.meter_maids_killed += 1
	Globals.meter_maid_death.emit()
	enemy.animated_sprite_2d.play("death")
	enemy.timer.stop()
	enemy.range_timer.stop()
	enemy.area_2d.monitorable = false
	enemy.area_2d.monitoring = false
	enemy.set_collision_layer_value(3, false)
	enemy.set_collision_mask_value(1, false)
	await enemy.get_tree().create_timer(1.5).timeout
	
	# Create blinking effect
	var tween = enemy.create_tween()
	#tween.set_loops(6) # 3 full blinks (fade out + fade in = 2 tweens per blink)

	tween.tween_property(enemy, "modulate:a", 0.0, 0.1)
	tween.chain().tween_property(enemy, "modulate:a", 1.0, 0.1).set_delay(0.2)

	tween.chain().tween_property(enemy, "modulate:a", 0.0, 0.1).set_delay(0.5)
	tween.chain().tween_property(enemy, "modulate:a", 1.0, 0.1).set_delay(0.2)
	tween.chain().tween_property(enemy, "modulate:a", 0.0, 0.1).set_delay(0.5)
	tween.chain().tween_property(enemy, "modulate:a", 1.0, 0.1).set_delay(0.2)
	tween.chain().tween_property(enemy, "modulate:a", 0.0, 0.1).set_delay(0.4)
	tween.chain().tween_property(enemy, "modulate:a", 1.0, 0.1).set_delay(0.2)
	# Wait for blinking to finish, then free the enemy
	await tween.finished
	enemy.queue_free()	
