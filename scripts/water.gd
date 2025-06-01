extends Node2D
@onready var splash_area_2d: Area2D = $SplashArea2D
@onready var audio_area_2d: Area2D = $AudioArea2D
@onready var running_water_audio: AudioStreamPlayer = $RunningWaterAudio
@onready var splash_audio: AudioStreamPlayer = $SplashAudio


func _ready() -> void:
	running_water_audio.volume_db -= 7
	audio_area_2d.body_entered.connect(func(body: Node2D): running_water_audio.play())
	audio_area_2d.body_exited.connect(func(body: Node2D): running_water_audio.stop())
	splash_area_2d.body_entered.connect(func(body: Node2D): splash_audio.play())
	#splash_area_2d.body_exited.connect(func(body: Node2D): splash_audio.stop())
