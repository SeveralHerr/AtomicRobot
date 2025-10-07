extends Node2D
const BRIEFCASE_BULLET_2 = preload("res://scenes/briefcase_bullet2.tscn")
const FINAL_BOSS = preload("res://scenes/final_boss.tscn")
@onready var boss_room_background_sprite: Sprite2D = $BossRoomBackgroundSprite

func _ready():
	start_briefcase_spawning()
	call_deferred("spawn_boss")
	
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
