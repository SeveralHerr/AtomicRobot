extends Node
const _21_THIS_IS_HEALING_ = preload("res://sounds/21 this is healing .wav")
const BOSS_TRACK = preload("res://sounds/boss.wav")
var audio: AudioStreamPlayer
var _boss_music := false

func _ready() -> void:
	audio  = AudioStreamPlayer.new()
	add_child(audio)
	# Stream, not the web default Sample: Sample decodes all 222 s to float PCM up front (~85 MB),
	# which OOM-kills the tab on a 1 GB Pi cabinet.
	audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	audio.stream= _21_THIS_IS_HEALING_
	audio.volume_db -= 10
	audio.play()
	Globals.boss_fight.connect(_on_boss_fight)
	# boss.wav has no loop points (and .import files aren't committed), so loop by hand.
	audio.finished.connect(func() -> void:
		if _boss_music:
			audio.play())


## Swap to the boss track for the fight and back after. Repeat calls are no-ops, so
## the room can announce "fight over" from both the finale and its own exit.
func _on_boss_fight(active: bool) -> void:
	if active == _boss_music:
		return
	_boss_music = active
	audio.stream = BOSS_TRACK if active else _21_THIS_IS_HEALING_
	audio.play()
