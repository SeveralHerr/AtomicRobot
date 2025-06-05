extends Node
class_name EnemyState

## Abstract base class for enemy states
## Concrete states should inherit from this and implement required methods

var enemy: Enemy

func _init(enemy: Enemy) -> void:
	self.enemy = enemy

## Called when entering this state
func enter_state() -> void:
	pass

## Called when exiting this state  
func exit_state() -> void:
	pass



## Called every frame (optional override)
func update(delta: float) -> void:
	pass
	
