extends Node

@onready var normal_audio_player: AudioStreamPlayer2D = $NormalAudioPlayer
@onready var boss_audio_player: AudioStreamPlayer2D = $BossAudioPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Globals.boss_fight.connect(_change_music)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _change_music(status: bool) -> void:
	if status:
		normal_audio_player.stop()
		boss_audio_player.play()
	else:
		normal_audio_player.play()
		boss_audio_player.stop()
