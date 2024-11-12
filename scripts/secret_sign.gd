extends Node

@onready var area_2d: Area2D = $Area2D
@onready var building_top: TileMapLayer = $"../TileMap/BuildingTop"
@onready var secret_area_2d: Area2D = $Sprite2D/Area2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

@export var unlock_text: String = ""
@export var hidden: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	if hidden:
		area_2d.body_entered.connect(_on_enter)
		area_2d.body_exited.connect(_on_exit)
		sprite_2d.hide()
		
	if not Globals.unlockables[0].unlocked:
		secret_area_2d.body_entered.connect(_on_enter_secret)
	else: 
		sprite_2d.queue_free()

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_enter(body: Node2D) -> void:
	if body is Player:
		building_top.z_index += 1
		if sprite_2d != null:
			sprite_2d.z_index += 1
			sprite_2d.show()
		
func _on_exit(body: Node2D) -> void:
	if body is Player:
		if sprite_2d != null:
			sprite_2d.z_index -= 1
			sprite_2d.hide()
		building_top.z_index -= 1

	
func _on_enter_secret(body: Node2D) -> void:
	if body is Player:
		Globals.unlockables[0].unlocked = true
		
		Globals.unlocked.emit("Unlocked", unlock_text)
		audio_stream_player_2d.play()
		sprite_2d.queue_free()
		secret_area_2d.body_entered.disconnect(_on_enter_secret)
