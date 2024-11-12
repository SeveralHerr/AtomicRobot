extends Node
class_name Unlockable

var unlock_text: String
var unlocked: bool = false
var description: String

func _init(_name: String, _unlock_text: String, _unlocked: bool, _description: String) -> void:
		name = _name
		unlock_text = _unlock_text
		unlocked = _unlocked
		description = _description
