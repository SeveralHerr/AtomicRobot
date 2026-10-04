class_name PartyFx
extends RefCounted

## Party Code payoff (Globals.party_mode): confetti bursts. CPUParticles2D, so it runs
## the same on the GL Compatibility / Web build. Each burst is a one-shot that frees
## itself, and is added BESIDE the thing that pops so hiding that thing can't hide it.

const GROUP := &"party_confetti"
const COLORS: Array[Color] = [Color("#ff4f7b"), Color("#ffd23f"), Color("#3bceac"),
	Color("#4d9dff"), Color("#b267ff"), Color("#ffffff")]
## A maid's killing "oof" squeaks up like a party horn.
const HORN_PITCH := 1.7
## Above the lane's y-sorted bodies, under the HUD.
const Z := 20

static var _paper: Texture2D = null


## True when `enemy` should burst: party mode on, and a meter maid (not the boss).
static func pops(enemy: Node) -> bool:
	return Globals.party_mode and not enemy is FinalBoss


## The maid's death in party mode: body vanishes in a confetti pop, oof goes up.
static func maid_pop(enemy: Enemy) -> void:
	var p := burst(enemy.get_parent(), enemy.animated_sprite_2d.global_position, 56, 520.0)
	p.z_index = enemy.z_index + Z  # over her own lane's bodies, whatever lane she died in
	enemy._death_blink_target().visible = false
	enemy.receive_hit_audio.pitch_scale = HORN_PITCH


## One-shot confetti pop at global `pos`, owned by `parent`.
static func burst(parent: Node, pos: Vector2, amount: int, speed: float) -> CPUParticles2D:
	return _spawn(parent, pos, _make(amount, speed, Vector2.UP, 70.0, 1.4, 1.2))


## A screen-sized party cannon (the title's acknowledgement): a tight, tall, slow jet.
static func cannon(parent: Node, pos: Vector2, dir: Vector2) -> CPUParticles2D:
	var p := _make(70, 1150.0, dir, 22.0, 2.2, 2.2)
	p.explosiveness = 0.6  # a short stream, not one blob
	return _spawn(parent, pos, p)


static func _make(amount: int, speed: float, dir: Vector2, spread: float, life: float,
		size: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "PartyConfetti"
	p.add_to_group(GROUP)
	p.texture = _paper_texture()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 640)
	p.damping_min = 90.0
	p.damping_max = 160.0
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	# A sideways wobble per flake, so paper flutters instead of falling like grit.
	p.tangential_accel_min = -80.0
	p.tangential_accel_max = 80.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 1.6 * size
	p.scale_amount_max = 2.6 * size
	p.color_initial_ramp = _palette()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.z_index = Z
	p.finished.connect(p.queue_free)
	return p


static func _spawn(parent: Node, pos: Vector2, p: CPUParticles2D) -> CPUParticles2D:
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	return p


## Discrete stops, so every flake is one solid party colour (no blends).
static func _palette() -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	for i in COLORS.size():
		offsets.append(float(i) / COLORS.size())
	g.offsets = offsets
	g.colors = PackedColorArray(COLORS)
	return g


## A 6x3 white paper strip; tinted per flake, spun by angular_velocity.
static func _paper_texture() -> Texture2D:
	if _paper == null:
		var img := Image.create(6, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_paper = ImageTexture.create_from_image(img)
	return _paper
