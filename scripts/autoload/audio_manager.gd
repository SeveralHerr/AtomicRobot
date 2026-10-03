extends Node
const _21_THIS_IS_HEALING_ = preload("res://sounds/21 this is healing .wav")
var audio: AudioStreamPlayer 

func _ready() -> void:
	audio  = AudioStreamPlayer.new()
	add_child(audio)
	# Stream, not the web default Sample: Sample decodes all 222 s to float PCM up front (~85 MB),
	# which OOM-kills the tab on a 1 GB Pi cabinet.
	audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	audio.stream= _21_THIS_IS_HEALING_
	audio.volume_db -= 10
	audio.play()
