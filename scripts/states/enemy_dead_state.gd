extends EnemyState
class_name DeadEnemyState

func enter_state() -> void:
	enemy.die()
