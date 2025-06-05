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

## Handle input events (optional override)
func handle_input(enemy: Enemy, event: InputEvent) -> void:
	pass

## Called every frame (optional override)
func update(enemy: Enemy, delta: float) -> void:
	pass
	
## Called during physics processing (required for movement states)
func physics_update(delta: float) -> void:
	pass
