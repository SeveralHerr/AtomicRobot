extends Node2D
class_name Crack

## Hidden secret wall. Five blows (melee via AttackState, or a Robot/Cass shot via
## LaneProjectile) crack it open: chunks fly, "SECRET!" pops, and an orb waits in
## the hole. Interact sends the orb flying to the HP bar (+1 orb) and reports
## Globals.secret_found("wall", path) — once.

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D
@onready var interact_label: Label = $InteractLabel
@onready var static_body_2d: StaticBody2D = $StaticBody2D
@onready var crack_audio: AudioStreamPlayer = $CrackAudio

const CAT_SCENE := preload("res://scenes/cat.tscn")
const OPEN_FRAME := 5
const PROMPT := "[interact] GRAB ORB"
const PROMPT_GOLD := Color("#FFC72C")
const PROMPT_FONT := preload("res://styles/white_font.tres")
## Reveal fanfare (character unlocks use it too: "you found something").
const REVEAL_STING := preload("res://sounds/Unlock.wav")
const CLAIM_CHIME := preload("res://sounds/coin5.ogg")
## Extra camera kick on top of HitFeel's: a wall is heavier than a meter maid.
const BLOW_SHAKE := 5.0
const BLOW_SHAKE_TIME := 0.2
const OPEN_SHAKE := 9.0
const OPEN_SHAKE_TIME := 0.4

## Where the comic word sits relative to the hole (world px).
const WORD_SIDE := 22.0
const WORD_RISE := 14.0

const GROUP := "cracks"

## Set on the window-building crack: a cat (scripts/cat.gd) climbs out onto the roof.
@export var releases_cat := false

var player: Player
var _opened := false
var _claimed := false
var _hole_orb: Sprite2D


func _ready() -> void:
	add_to_group(GROUP)
	area_2d.body_entered.connect(_on_area_entered)
	area_2d.body_exited.connect(_on_area_exited)
	player = get_tree().get_first_node_in_group("player")
	hide()
	interact_label.hide()
	_style_prompt()
	animated_sprite_2d.frame = 0


func _process(_delta: float) -> void:
	if interact_label.visible and Input.is_action_just_pressed("Interact"):
		claim()


func is_open() -> bool:
	return _opened


## Radius of the hit circle (world px) a shot has to reach.
func hit_radius() -> float:
	var shape := area_2d.get_child(0) as CollisionShape2D
	var circle := shape.shape as CircleShape2D if shape else null
	return circle.radius * absf(area_2d.global_scale.y) if circle else 0.0


func _on_area_exited(body: Node2D) -> void:
	if body is Player:
		interact_label.hide()


func _on_area_entered(body: Node2D) -> void:
	if body is Player and _opened and not _claimed:
		interact_label.show()


## A blow from `attacker` (the player, or the shot that hit): crack + full feel.
## Blows on an open wall do nothing.
func take_blow(attacker: Node2D) -> void:
	if _opened:
		return
	receive_hit()
	HitFeel.hit_landed(attacker, self, _opened)
	# The word goes up and away from the attacker so it never covers their face.
	var away := signf(_hole_center().x - attacker.global_position.x)
	var word_at := _hole_center() + Vector2(away * WORD_SIDE, -WORD_RISE)
	if _opened:
		ScreenShake.apply_shake(OPEN_SHAKE, OPEN_SHAKE_TIME)
		ComicPopup.spawn(self, word_at, &"secret")
	else:
		ScreenShake.apply_shake(BLOW_SHAKE, BLOW_SHAKE_TIME)
		SecretFx.brick_burst(self, _hole_center(), 8, 120.0)
		ComicPopup.spawn(self, word_at, &"smash")


## One step of the crack. The fifth opens the wall.
func receive_hit() -> void:
	if not visible:
		show()
	crack_audio.play()
	if animated_sprite_2d.frame < OPEN_FRAME:
		animated_sprite_2d.frame += 1
	if animated_sprite_2d.frame == OPEN_FRAME and not _opened:
		_open()


func _open() -> void:
	_opened = true
	if is_instance_valid(static_body_2d):
		static_body_2d.queue_free()
	interact_label.show()
	_paint_interior()
	SecretFx.brick_burst(self, _hole_center(), 28, 240.0)
	SecretFx.play_once(self, REVEAL_STING, -4.0)
	_hole_orb = Sprite2D.new()
	_hole_orb.texture = SecretFx.small_orb()
	_hole_orb.scale = Vector2.ONE * SecretFx.HOLE_ORB_PX / float(_hole_orb.texture.get_width())
	add_child(_hole_orb)
	_hole_orb.global_position = _hole_center()
	var bob := _hole_orb.create_tween().set_loops()
	bob.tween_property(_hole_orb, "position:y", _hole_orb.position.y - 3.0, 0.45).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_hole_orb, "position:y", _hole_orb.position.y, 0.45).set_trans(Tween.TRANS_SINE)
	if releases_cat:
		var cat: Node2D = CAT_SCENE.instantiate()
		cat.position = animated_sprite_2d.position  # out of the hole itself
		add_child(cat)


## Takes the orb: it flies to the HP bar and heals on arrival. Pays out once.
func claim() -> void:
	if not _opened or _claimed:
		return
	_claimed = true
	interact_label.hide()
	Globals.secret_found.emit("wall", str(get_path()))
	SecretFx.play_once(self, CLAIM_CHIME)
	var from := _hole_center()
	if is_instance_valid(_hole_orb):
		from = _hole_orb.global_position
		_hole_orb.queue_free()
	SecretFx.fly_orb(self, from, _pay_out)


func _pay_out() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		player.add_heart(1)


func _hole_center() -> Vector2:
	return animated_sprite_2d.global_position


func _paint_interior() -> void:
	var tex := animated_sprite_2d.sprite_frames.get_frame_texture(animated_sprite_2d.animation, OPEN_FRAME)
	var mat := ShaderMaterial.new()
	mat.shader = SecretFx.INTERIOR_SHADER
	if tex is AtlasTexture:
		var size := Vector2(tex.atlas.get_size())
		var r: Rect2 = tex.region
		mat.set_shader_parameter("region", Vector4(r.position.x / size.x, r.position.y / size.y,
			r.size.x / size.x, r.size.y / size.y))
	mat.set_shader_parameter("open", 1.0)
	animated_sprite_2d.material = mat


func _style_prompt() -> void:
	var s := LabelSettings.new()
	s.font = PROMPT_FONT
	s.font_size = 20
	s.font_color = PROMPT_GOLD
	s.outline_size = 6
	s.outline_color = Color.BLACK
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_offset = Vector2(1, 2)
	interact_label.label_settings = s
	interact_label.text = PROMPT
