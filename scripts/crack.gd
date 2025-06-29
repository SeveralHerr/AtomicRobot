extends Node2D
class_name Crack
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D
@onready var interact_label: Label = $InteractLabel
@onready var static_body_2d: StaticBody2D = $StaticBody2D
@onready var crack_audio: AudioStreamPlayer = $CrackAudio

var hits: int = 0
var player: Player

func _ready() -> void:
	area_2d.body_entered.connect(_on_area_entered)
	area_2d.body_exited.connect(_on_area_exited)
	player = get_tree().get_first_node_in_group("player")
	#static_body_2d.set_collision_mask_value(1, false)
	hide()
	interact_label.hide()
	animated_sprite_2d.frame = 0

func _process(_delta: float) -> void:
	if interact_label.visible and Input.is_action_just_pressed("Interact"):
		area_2d.body_entered.disconnect(_on_area_entered)
		area_2d.body_exited.disconnect(_on_area_exited)
		if player:
			player.add_heart(1)
		interact_label.hide()
	
func _on_area_exited(body: Node2D) -> void:
		interact_label.hide()	
		
func _on_area_entered(body: Node2D) -> void:
	if body is Player and animated_sprite_2d.frame == 6 - 1:
		interact_label.show()


func receive_hit() -> void:
	if not visible:
		show()
	crack_audio.play()
	#hits += 1
	var frame_count = 6
	if animated_sprite_2d.frame < frame_count - 1:
		animated_sprite_2d.frame += 1
	if animated_sprite_2d.frame == frame_count - 1:
		# Wall is open
		if is_instance_valid(static_body_2d):
			static_body_2d.queue_free()
		interact_label.show()
