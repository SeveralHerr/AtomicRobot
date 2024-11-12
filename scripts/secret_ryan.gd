extends Node

@onready var area_2d: Area2D = $Area2D

@onready var secret_area_2d: Area2D = $Sprite2D/Area2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

@export var unlock_text: String = ""
@export var hidden: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	if not Globals.character_dict["Ryan"].unlocked:
		secret_area_2d.body_entered.connect(_on_enter_secret)
	else: 
		sprite_2d.queue_free()

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _on_enter_secret(body: Node2D) -> void:
	if body is Player:
		Globals.character_dict["Ryan"].unlocked = true
		
		Globals.unlocked.emit("Unlocked", unlock_text)
		audio_stream_player_2d.play()
		sprite_2d.queue_free()
		secret_area_2d.body_entered.disconnect(_on_enter_secret)
