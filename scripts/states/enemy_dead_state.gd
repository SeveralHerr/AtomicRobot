extends EnemyState
class_name DeadEnemyState

func enter_state(enemy: Enemy) -> void:
	enemy.die()
