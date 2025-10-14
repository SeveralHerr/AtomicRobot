extends Node2D
const BRIEFCASE_BULLET_2 = preload("res://scenes/briefcase_bullet2.tscn")
const FINAL_BOSS = preload("res://scenes/final_boss.tscn")
@onready var boss_room_background_sprite: Sprite2D = $BossRoomBackgroundSprite
@onready var boss_words_label: Label = $UI/BossIntroContainer/BossWordsLabel
@onready var player: Player = $Player

@onready var final_boss_label: Label = $UI/BossIntroContainer/VBoxContainer/FinalBossLabel
@onready var entrance_trigger: Area2D = $EntranceTrigger

var intro_played: bool = false

func _ready():
	player.set_process(false)
	# Set labels to invisible initially
	boss_words_label.modulate.a = 0
	final_boss_label.modulate.a = 0
	boss_words_label.visible = true
	final_boss_label.visible = true

	# Connect entrance trigger
	if entrance_trigger:
		entrance_trigger.body_entered.connect(_on_player_entered)
	
func _on_player_entered(body):
	if intro_played:
		return

	if body.is_in_group("player"):
		intro_played = true
		play_boss_intro_sequence()

func play_boss_intro_sequence():
	# Sequence: Final Boss label -> Boss Words label -> Spawn boss

	# Phase 1: Fade in "Final Boss" label
	var tween1 = create_tween()
	tween1.tween_property(final_boss_label, "modulate:a", 1.0, 0.5)
	tween1.tween_interval(1.5)
	tween1.tween_property(final_boss_label, "modulate:a", 0.0, 0.5)

	# Phase 2: Fade in "Boss Words" label (wait for phase 1 to complete)
	await tween1.finished
	spawn_boss()
	start_briefcase_spawning()
	player.set_process(true)
	var tween2 = create_tween()
	tween2.tween_property(boss_words_label, "modulate:a", 1.0, 0.5)
	tween2.tween_interval(2.0)
	tween2.tween_property(boss_words_label, "modulate:a", 0.0, 0.5)

func spawn_boss():
	var instance = FINAL_BOSS.instantiate()
	add_child(instance)

func start_briefcase_spawning():
	var timer = Timer.new()
	timer.wait_time = 0.2
	timer.one_shot = false
	timer.timeout.connect(spawn_falling_briefcase)
	add_child(timer)
	timer.start()

func spawn_falling_briefcase():
	if not boss_room_background_sprite:
		return
	
	var sprite_rect = boss_room_background_sprite.get_rect()
	var sprite_size = sprite_rect.size
	var sprite_pos = boss_room_background_sprite.global_position
	
	# Random X position along the top of the sprite
	var random_x = randf_range(sprite_pos.x - sprite_size.x/2, sprite_pos.x + sprite_size.x/2)
	var spawn_pos = Vector2(random_x, sprite_pos.y - sprite_size.y/2)
	
	# Target position below the sprite
	var target_pos = Vector2(random_x, sprite_pos.y + sprite_size.y/2 + 200)
	
	Utils.throw_briefcase(spawn_pos, target_pos, self, false, 0.2, true)
