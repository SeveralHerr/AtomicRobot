extends Node
class_name CharacterSounds

var jump_sound: AudioStream
var hit_sound: AudioStream  
var land_sound: AudioStream
var attack_sound: AudioStream

func _init(_jump_sound: AudioStream, _hit_sound: AudioStream, _land_sound: AudioStream, _attack_sound: AudioStream) -> void:
	jump_sound = _jump_sound
	hit_sound = _hit_sound
	land_sound = _land_sound
	attack_sound = _attack_sound
