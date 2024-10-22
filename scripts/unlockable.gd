extends Node
class_name Unlockable

@export var unlock_text: String
@export var unlocked: bool = false

func _init(_name: String, _unlock_text: String, _unlocked: bool) -> void:
		name = _name
		unlock_text = _unlock_text
		unlocked = _unlocked
