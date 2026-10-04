extends Sprite2D

const FINAL_BOSS = preload("res://scenes/boss_room.tscn")
## The boss door slams behind the player as the street fades out.
const DOOR_SLAM: AudioStream = preload("res://sounds/711657__discofield__stone-crash.wav")

@onready var area_2d: Area2D = $Area2D
func _ready() -> void:
	area_2d.body_entered.connect(_on_area_entered)

func _on_area_entered(body: Node2D) -> void:
	if body is Player:
		# The boss room has its own Player; hand it this one's health.
		Globals.carry_health((body as Player).health)
		PowerupSystem.carry_through_door()
		# Deferred: this runs inside a physics callback, and the fade pauses the tree.
		call_deferred("change_scene")

func change_scene() -> void:
	Transition.change_scene_to_packed(FINAL_BOSS, DOOR_SLAM)
