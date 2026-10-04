extends Node2D

## The boss room is the fight's director: it plays the intro, then turns the boss's
## phase signals into waves — telegraphed ceiling drops and meter-maid
## reinforcements — plus the banners, HUD bar and finale juice. Tuning lives in
## BossRules; the boss's own attacks live in his states.

const FINAL_BOSS = preload("res://scenes/final_boss.tscn")
const THUD = preload("res://sounds/711657__discofield__stone-crash.wav")
const BOOM = preload("res://sounds/explosion.wav")
const HEART = preload("res://scenes/atomic_heart_pickup.tscn")

## Boss walk-in, in world X: from just off the right of the opening view to his mark.
const BOSS_ENTER_FROM := 150.0
const BOSS_MARK := -20.0
const WALK_IN_TIME := 1.5
## Ceiling drops and reinforcements land within this many px of the player.
const WAVE_REACH := 250.0
## HUD out before the letterbox slides in (real seconds).
const HUD_FADE_TIME := 0.15
## Banner stripe colour per phase: red, then hotter.
const PHASE_TINTS: Array[Color] = [ComicStyle.RED, ComicStyle.ORANGE, ComicStyle.PLUM]

@onready var boss_room_background_sprite: Sprite2D = $Environment/BossRoomBackgroundSprite
@onready var ui: CanvasLayer = $UI
@onready var player: Player = $Player
@onready var entrance_trigger: Area2D = $Triggers/EntranceTrigger

var intro_played: bool = false
var is_player_dead: bool = false
var boss: FinalBoss
var bar: BossHealthBar
var banner: BossBanner
var rng := RandomNumberGenerator.new()
var _drop_timer: Timer
var _floor_y: float = 0.0


func _ready():
	_set_player_frozen(true)
	# Seeded off the global RNG so the autoplay bot's `seed` still pins every volley.
	rng.seed = randi()
	bar = BossHealthBar.new()
	ui.add_child(bar)
	banner = BossBanner.new()
	ui.add_child(banner)
	banner.landed.connect(_thud.bind(14.0))
	_drop_timer = Timer.new()
	_drop_timer.timeout.connect(_drop_volley)
	add_child(_drop_timer)
	if entrance_trigger:
		entrance_trigger.body_entered.connect(_on_player_entered)
	Globals.player_death.connect(_on_player_death)


func _exit_tree() -> void:
	BossJuice.reset_time()
	# Leaving mid-intro must not hand the next level a held-hidden HUD.
	HudFade.release(get_tree(), HudFade.CINEMATIC)
	Globals.boss_fight.emit(false)


func _set_player_frozen(frozen: bool) -> void:
	player.set_process(not frozen)
	player.set_physics_process(not frozen)
	player.set_process_input(not frozen)


func _on_player_death():
	is_player_dead = true
	_drop_timer.stop()


func _on_player_entered(body):
	if intro_played:
		return
	if body.is_in_group("player"):
		intro_played = true
		# Deferred: this runs inside the trigger's physics callback, and the intro
		# spawns the boss (bodies + areas) — not allowed mid-flush.
		play_boss_intro_sequence.call_deferred()


# --- Intro -----------------------------------------------------------------------

## Letterbox -> boss strides in -> his line in a speech bubble -> FINAL BOSS slams
## onto a stripe -> card slides in and fills -> FIGHT! bursts -> controls back.
## The HUD sits out the cinematic — the HP orbs (z_index 2) draw over the bars —
## so it is gone before the bars slide in and back only once they have slid out.
func play_boss_intro_sequence():
	Globals.boss_fight.emit(true)
	HudFade.fade(get_tree(), HudFade.CINEMATIC, 0.0, HUD_FADE_TIME)
	await get_tree().create_timer(HUD_FADE_TIME, true, false, true).timeout
	var bars := BossJuice.letterbox_in(ui)
	boss = spawn_boss()
	await _walk_in()
	var p := BossRules.params(0)
	await banner.say(p["line"], boss, 0.8)
	await banner.slam_title(p["title"], p["sub"], 1.1, PHASE_TINTS[0])
	BossJuice.letterbox_out(bars)
	HudFade.fade(get_tree(), HudFade.CINEMATIC, 1.0, 0.3, BossJuice.LETTERBOX_TIME)
	bar.show_bar(boss.max_health)
	await banner.slam_title("FIGHT!", "", 0.35, ComicStyle.RED, true)
	BossJuice.flash(ui, Color(1, 1, 1, 0.5), 0.25)
	_floor_y = player.global_position.y + player.foot_offset()
	_set_player_frozen(false)
	boss.begin_fight()


func spawn_boss() -> FinalBoss:
	var b: FinalBoss = FINAL_BOSS.instantiate()
	add_child(b)
	# top_level: these are world coordinates. He drops onto the floor under gravity.
	b.global_position = Vector2(BOSS_ENTER_FROM, player.global_position.y - 30.0)
	b.health_changed.connect(func(hp: int, _m: int) -> void: bar.set_health(hp))
	# Deferred: hits land inside a physics callback, and both handlers add or kill
	# bodies with Area2Ds (maids, the heart) — not allowed mid-flush.
	b.phase_changed.connect(_on_phase_changed, CONNECT_DEFERRED)
	b.defeated.connect(_on_boss_defeated, CONNECT_DEFERRED)
	return b


func _walk_in() -> void:
	boss.set_physics_process(true)
	boss.set_facing(-1)
	boss.animated_sprite_2d.play("walk")
	var tw := boss.create_tween()
	tw.tween_property(boss, "global_position:x", BOSS_MARK, WALK_IN_TIME)
	await tw.finished
	boss.animated_sprite_2d.play("idle")


# --- Waves -----------------------------------------------------------------------

func _on_phase_changed(phase: int) -> void:
	var p := BossRules.params(phase)
	_thud(12.0)
	BossJuice.flash(ui, Color(0.85, 0.1, 0.1, 0.45), 0.5)
	_send_maids(p["maids"])
	_drop_heart()
	_drop_timer.stop()
	if p["drop_every"] > 0.0:
		_drop_timer.start(p["drop_every"])
	bar.set_tint(FinalBoss.PHASE_TINTS[phase])
	await banner.slam_title(p["title"], p["sub"], 0.7, PHASE_TINTS[phase])
	# After the stripe clears: the bubble would sit under it otherwise.
	if boss.fighting:
		banner.say(p["line"], boss, 0.9)


## One volley of telegraphed ceiling drops near the player: floor markers first,
## then the briefcases, always spaced so there is a gap to stand in.
func _drop_volley() -> void:
	if is_player_dead or boss == null or not boss.fighting:
		return
	var lim := _room_x_limits()
	var left := maxf(player.global_position.x - WAVE_REACH, lim.x)
	var right := minf(player.global_position.x + WAVE_REACH, lim.y)
	var xs := BossRules.drop_xs(boss.params()["drop_count"], left, right, rng)
	for x in xs:
		var marker := DropMarker.new()
		add_child(marker)
		marker.global_position = Vector2(x, _floor_y)
	# Released early: the fall itself eats the rest of the warning.
	await get_tree().create_timer(BossRules.DROP_WARN * 0.55).timeout
	if is_player_dead or not boss.fighting:
		return
	var top := _ceiling_y()
	for x in xs:
		Utils.throw_briefcase(Vector2(x, top), Vector2(x, _floor_y + 300.0), self, false, 0.2, true)


func _send_maids(count: int) -> void:
	var lim := _room_x_limits()
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := clampf(player.global_position.x + side * (WAVE_REACH + 40.0), lim.x + 20.0, lim.y - 20.0)
		var maid: Enemy = (EnemySpawner.METER_MAID_MELEE if i % 2 == 0 else EnemySpawner.METER_MAID).instantiate()
		maid.persist = true
		maid.spawn_grace = 1.2
		add_child(maid)
		maid.global_position = Vector2(x, player.global_position.y - 20.0)


## Each phase change knocks an atomic heart loose: the breather that makes the next,
## harder phase winnable for the two-orb characters.
func _drop_heart() -> void:
	var heart: Node2D = HEART.instantiate()
	add_child(heart)
	var from := boss.global_position + Vector2(0.0, -30.0)
	var to := Vector2(boss.global_position.x + boss.facing * 70.0, _floor_y - 22.0)  # toward the player
	heart.global_position = from
	var tw := heart.create_tween().set_parallel(true)
	tw.tween_property(heart, "global_position:x", to.x, 0.6)
	tw.tween_property(heart, "global_position:y", to.y, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# --- Finale ----------------------------------------------------------------------

func _on_boss_defeated() -> void:
	_drop_timer.stop()
	Globals.boss_fight.emit(false)
	bar.hide_bar()
	BossJuice.flash(ui, Color.WHITE, 0.9)
	ScreenShake.apply_shake(14.0, 1.2)
	_play(BOOM)
	banner.slam_title("ADJOURNED!", "MEETING OVER", 1.0, ComicStyle.RED, true)
	# Nothing may hurt the player once the boss is down: clear the air and the crew.
	# (Maids are reparented onto the lane sort layer, so find them by group.)
	for c in get_children():
		if c is Bullet:
			c.queue_free()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != boss and e is Enemy and not e.is_dead:
			e.receive_hit(99)


# --- Helpers ---------------------------------------------------------------------

func _thud(strength: float) -> void:
	_play(THUD)
	ScreenShake.apply_shake(strength, 0.6)


func _play(stream: AudioStream) -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = -6.0
	sfx.finished.connect(sfx.queue_free)
	add_child(sfx)
	sfx.play()


## World X range the camera may show — the room's walls, as far as play goes.
func _room_x_limits() -> Vector2:
	var cam := player.camera_2d
	return Vector2(cam.limit_left + 30.0, cam.limit_right - 30.0)


func _ceiling_y() -> float:
	var s := boss_room_background_sprite
	return s.global_position.y - s.get_rect().size.y * 0.5
