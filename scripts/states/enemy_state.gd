extends Node
class_name EnemyState

## Abstract base class for enemy states
## Concrete states should inherit from this and implement required methods

var enemy: Enemy

## Called when entering this state
func enter_state(enemy: Enemy) -> void:
	self.enemy = enemy

## Called when exiting this state  
func exit_state(enemy: Enemy) -> void:
	pass



## Called every frame (optional override)
func update(delta: float) -> void:
	pass
	
