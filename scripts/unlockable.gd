extends Node
class_name Unlockable

var unlock_text: String
var unlocked: bool = false
var description: String
var sprite_frames: Resource
var unlock_hint: String

func _init(_name: String, _unlock_text: String, _unlocked: bool, _description: String, _sprite_frames: Resource, _unlock_hint: String) -> void:
		name = _name
		unlock_text = _unlock_text
		unlocked = _unlocked
		description = _description
		sprite_frames = _sprite_frames
		unlock_hint = _unlock_hint
