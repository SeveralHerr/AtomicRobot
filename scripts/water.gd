extends Node2D

const SPLASH_PARTICLES = preload("res://scenes/splash_particles.tscn")
const BUBBLE_PARTICLES = preload("res://scenes/bubble_particles.tscn")

@onready var splash_area_2d: Area2D = $SplashArea2D
@onready var audio_area_2d: Area2D = $AudioArea2D
@onready var running_water_audio: AudioStreamPlayer = $RunningWaterAudio
@onready var splash_audio: AudioStreamPlayer = $SplashAudio

var start_y: float = 2
var bubble_start_y: float = 75

func _ready() -> void:
	running_water_audio.volume_db = -40 # Start muted
	audio_area_2d.body_entered.connect(func(body: Node2D):
		if body is Player:
			_fade_in_running_water())
			
	audio_area_2d.body_exited.connect(func(body: Node2D):
		if body is Player:
			_fade_out_running_water())
			
	splash_area_2d.body_entered.connect(func(body: Node2D):
		_handle_splash(body)
		
		_handle_bubbles(body)
		)
	#asplash_area_2d.body_exited.connect(func(body: Node2D): splash_audio.stop())
	
func _handle_bubbles(body: Node2D) -> void:
	var instance = BUBBLE_PARTICLES.instantiate()
	add_child(instance)
	instance.position = Vector2(body.position.x, bubble_start_y)
	instance.emitting = true
	pass

func _handle_splash(body: Node2D) -> void:
	var instance = SPLASH_PARTICLES.instantiate()
	add_child(instance)
	instance.position = Vector2(body.position.x, start_y)
	instance.emitting = true
	splash_audio.play()
	await get_tree().create_timer(1).timeout
	instance.queue_free()
	pass

func _fade_in_running_water():
	var tween = create_tween()
	running_water_audio.play()
	tween.tween_property(running_water_audio, "volume_db", -7, 1)

func _fade_out_running_water():
	var tween = create_tween()
	tween.tween_property(running_water_audio, "volume_db", -40, 1)
	tween.tween_callback(Callable(running_water_audio, "stop"))
