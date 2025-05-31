extends Node
const _21_THIS_IS_HEALING_ = preload("res://sounds/21 this is healing .wav")
var audio: AudioStreamPlayer 

func _ready() -> void:
	audio  = AudioStreamPlayer.new()
	add_child(audio)
	audio.stream= _21_THIS_IS_HEALING_
	audio.play()
