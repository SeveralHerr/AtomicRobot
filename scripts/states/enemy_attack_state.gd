extends AttackPlayerState
class_name EnemyAttackState

## Extended attack state with longer range for special enemies like TrainMeterMaid

func enter_state(enemy: Enemy) -> void:
	enemy.attack_range = 250  # Extended range for special enemies
	super.enter_state(enemy)
