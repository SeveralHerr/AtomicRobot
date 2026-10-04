extends Node
class_name MicroCutscene

## Plays one street cut scene (CutsceneShots): freezes the fight but not the city —
## the player idles, enemies and buffs hold still, leaves and cars keep moving —
## then a cut-scene camera glides through the shots under letterbox bars with a
## comic caption, and glides back to exactly where the play camera sits before
## handing over. Holding a button skips; a tap only shows the prompt, so mashing
## through the front end can't eat the story.

signal finished(skipped: bool)

## True while any cut scene runs. The autoplay bot and the enemy spawner read it.
static var playing := false

const LAYER := 3
## Letterbox bars. The wide shots sit on the camera's bottom limit, so the road lane
## the player stands on is near the bottom edge: a 62px bar (the boss room's) hid
## the player's feet in the opening.
const TOP_BAR := 130.0
const BOTTOM_BAR := 48.0
const HUD_FADE := 0.15
const RETURN_TIME := 0.9
const SKIP_RETURN_TIME := 0.3
## Seconds a skip button must be held. A key already down when the scene starts
## (a run key, the press that left the splash) only counts once let go and pressed again.
const SKIP_HOLD := 0.8
## Polled, not evented, so the touch buttons (Input.action_press) skip too. Not
## "pause": the pause menu pauses the scene instead.
const SKIP_ACTIONS: Array[StringName] = [&"ui_accept", &"Attack", &"Interact"]
## Longest a body may stay live while it falls to the ground before it is held anyway.
const SETTLE_MAX := 1.0
const THUNDER := preload("res://sounds/729539__infinita08__lightning-thunder-crack.wav")

var id := ""
var _spec: Dictionary
var _player: Player
var _cam: Camera2D
var _layer: CanvasLayer
var _bars: Array[ColorRect] = []
var _card: CaptionCard
var _dusk: CanvasModulate
var _shots: Tween
var _cues: Tween
var _age := 0.0
var _skip: SkipPrompt
## Seconds the skip buttons have been held; armed once none were down.
var _held := 0.0
var _armed := false
var _outro := false
var _skipped := false
var _was_god := false
## [enemy, its process_mode before the freeze]
var _frozen_enemies: Array = []
## Bodies still falling to the ground, held as each one lands.
var _settling: Array = []
var _shake := 0.0


## Start cut scene `scene_id` for `player`, hosted under `host`. `instant`: open on
## the first shot with the bars already in (the level's own opening, revealed by the
## scene fade) instead of sliding in from the play camera.
static func start(host: Node, scene_id: String, player: Player, instant := false) -> MicroCutscene:
	var c := MicroCutscene.new()
	c.id = scene_id
	c._spec = CutsceneShots.scene(scene_id)
	c._player = player
	c.set_meta(&"instant", instant)
	host.add_child(c)
	return c


func _ready() -> void:
	name = "MicroCutscene_" + id
	playing = true
	var instant: bool = get_meta(&"instant")
	_freeze(true)
	# A door's STREET CLEAR! may still be up: it clears as the camera pulls back.
	get_tree().call_group(BossBanner.GROUP, "clear_title")
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	_card = CaptionCard.new()
	_layer.add_child(_card)
	_card.landed.connect(func() -> void: _shake = 7.0)
	_cam = Camera2D.new()
	_cam.limit_bottom = int(CutsceneShots.LIMIT_BOTTOM)
	add_child(_cam)
	var first: Dictionary = _spec["shots"][0]
	if instant:
		_cam.global_position = first["at"]
		_cam.zoom = Vector2.ONE * first["zoom"]
	else:
		_cam.global_position = CutsceneShots.play_center(_player.global_position)
		_cam.zoom = Vector2.ONE * CutsceneShots.PLAY_ZOOM
	_cam.make_current()
	_cam.reset_smoothing()
	HudFade.fade(get_tree(), HudFade.CINEMATIC, 0.0, HUD_FADE)
	_bars = BossJuice.letterbox_in(_layer, TOP_BAR, BOTTOM_BAR)
	# The caption hangs off the top bar, so it draws over it.
	_card.move_to_front()
	_skip = SkipPrompt.new()
	_layer.add_child(_skip)
	if instant:
		_snap_open()
	_run_shots()
	_run_cues()


## The level fade reveals the first frame, so the HUD and bars must already be in
## place (their tweens wait out the paused fade).
func _snap_open() -> void:
	for node in get_tree().get_nodes_in_group(HudFade.CINEMATIC):
		if node is CanvasItem:
			node.modulate.a = 0.0
	var view := _layer.get_viewport().get_visible_rect().size
	_bars[0].position.y = 0.0
	_bars[1].position.y = view.y - _bars[1].size.y


func _run_shots() -> void:
	_shots = create_tween()
	for s: Dictionary in _spec["shots"]:
		if s["move"] > 0.0:
			_shots.tween_property(_cam, "global_position", s["at"], s["move"]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_shots.parallel().tween_property(_cam, "zoom", Vector2.ONE * s["zoom"], s["move"]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			_shots.tween_callback(func() -> void:
				_cam.global_position = s["at"]
				_cam.zoom = Vector2.ONE * s["zoom"])
		if s["hold"] > 0.0:
			_shots.tween_interval(s["hold"])
	_shots.tween_callback(_end.bind(false))


## Timed extras on their own tween, so a skip kills them with the shots.
func _run_cues() -> void:
	_cues = create_tween().set_parallel()
	for c: Dictionary in _spec["captions"]:
		_cues.tween_callback(_card.present.bind(c["kicker"], c["title"], c["tint"])).set_delay(c["at"])
	for p: Dictionary in _spec.get("pops", []):
		_cues.tween_callback(func() -> void: ComicPopup.spawn(self, p["pos"], p["kind"])).set_delay(p["at"])
	if _spec.has("gust_at"):
		_cues.tween_callback(LeafSystem.trigger_area_gust.bind(_spec["gust"], 420.0, 1.0)).set_delay(_spec["gust_at"])
	if _spec.has("dusk"):
		_dusk = CanvasModulate.new()
		get_tree().current_scene.add_child(_dusk)
		_cues.tween_property(_dusk, "color", _spec["dusk"], 1.2)
	if _spec.has("thunder_at"):
		_cues.tween_callback(_thunder).set_delay(_spec["thunder_at"])


func _thunder() -> void:
	_flash(0.75, 0.45)
	# Lightning flickers: a second, weaker strike right behind the first.
	create_tween().tween_callback(_flash.bind(0.45, 0.3)).set_delay(0.14)
	_shake = 10.0
	var p := AudioStreamPlayer.new()
	p.stream = THUNDER
	p.volume_db = -6.0
	p.finished.connect(p.queue_free)
	# On the scene, not this node: the crack rolls on after the camera hands back.
	get_tree().current_scene.add_child(p)
	p.play()


## Lightning lights the street, not the letterbox: the flash goes under the bars.
func _flash(alpha: float, seconds: float) -> void:
	BossJuice.flash(_layer, Color(1, 1, 1, alpha), seconds)
	_layer.move_child(_layer.get_child(_layer.get_child_count() - 1), 0)


func _process(delta: float) -> void:
	_age += delta
	_track_skip(delta)
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 30.0)
		_cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))


## Hold to skip: fill the ring while held, drain it when let go.
func _track_skip(delta: float) -> void:
	if _outro:
		return
	var down := skip_held()
	if not _armed:
		_armed = not down
		return
	if down and _held == 0.0:
		_skip.show_prompt(true)
	if down:
		_held += delta
		if _held >= SKIP_HOLD:
			_end(true)
	elif _held > 0.0:
		_held = 0.0
		_skip.show_prompt(false)
	_skip.progress = _held / SKIP_HOLD


static func skip_held() -> bool:
	for a in SKIP_ACTIONS:
		if Input.is_action_pressed(a):
			return true
	return false


## Glide back to the play camera's framing, then hand it over.
func _end(skipped: bool) -> void:
	if _outro:
		return
	_outro = true
	_skipped = skipped
	if _shots:
		_shots.kill()
	if _cues:
		_cues.kill()
	var back := SKIP_RETURN_TIME if skipped else RETURN_TIME
	_skip.show_prompt(false)
	_card.leave(0.15 if skipped else 0.3)
	if _dusk:
		var d := _dusk.create_tween()
		d.tween_property(_dusk, "color", Color.WHITE, back)
		d.tween_callback(_dusk.queue_free)
	var tw := create_tween().set_parallel()
	tw.tween_property(_cam, "global_position", CutsceneShots.play_center(_player.global_position), back).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_cam, "zoom", Vector2.ONE * CutsceneShots.PLAY_ZOOM, back).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_cam, "offset", Vector2.ZERO, back)
	await tw.finished
	_hand_back()


func _hand_back() -> void:
	_shake = 0.0
	if is_instance_valid(_player) and _player.camera_2d:
		# The play camera didn't scroll while it wasn't current: bring it up to date
		# before showing it, or it slides in from wherever it last looked.
		_player.camera_2d.make_current()
		_player.camera_2d.force_update_scroll()
		_player.camera_2d.reset_smoothing()
	BossJuice.letterbox_out(_bars)
	HudFade.fade(get_tree(), HudFade.CINEMATIC, 1.0, 0.3, BossJuice.LETTERBOX_TIME)
	_freeze(false)
	playing = false
	finished.emit(_skipped)
	# Outlive the bars' slide-out: they are children of this node's layer.
	await get_tree().create_timer(BossJuice.LETTERBOX_TIME + 0.05).timeout
	queue_free()


func _exit_tree() -> void:
	# Torn down mid-scene (level change): never leave the flag or a held HUD fade.
	if playing and not _outro:
		playing = false
		PowerupSystem.hold(false)
		HudFade.release(get_tree(), HudFade.CINEMATIC)
	if is_instance_valid(_dusk):
		_dusk.queue_free()


## The fight stands still for the scene: the player idles, can't be hurt and can't
## act; enemies stop mid-stride; power-up timers hold. Each body is held only once
## it is on the ground: the level's opening starts the frame the level loads, when
## the player and the roof maid are still at their spawn heights, and freezing them
## there left both floating for the whole shot.
func _freeze(on: bool) -> void:
	PowerupSystem.hold(on)
	if on:
		_was_god = _player.god_mode
		_player.god_mode = true
		_player.set_process_input(false)
		_settling = [_player]
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.process_mode != Node.PROCESS_MODE_DISABLED:
				_settling.append(e)
		_settle()
		return
	_settling.clear()
	if is_instance_valid(_player):
		_player.god_mode = _was_god
		_player.set_process(true)
		_player.set_physics_process(true)
		_player.set_process_input(true)
	for pair: Array in _frozen_enemies:
		if is_instance_valid(pair[0]):
			pair[0].process_mode = pair[1]
	_frozen_enemies.clear()


## Hold every body that has landed, and anything still airborne SETTLE_MAX in
## (a window maid never touches a floor).
func _settle() -> void:
	for body in _settling.duplicate():
		if not is_instance_valid(body):
			_settling.erase(body)
		elif _age >= SETTLE_MAX or _landed(body):
			_hold(body)
			_settling.erase(body)


func _landed(body: Node) -> bool:
	if body == _player:
		return _player.is_settled()
	# Enemies rarely read is_on_floor() after a step (their lane mover snaps them);
	# a captured street baseline and no fall speed means they have landed.
	if body is Enemy:
		return body.is_on_floor() or (body.lane_floor_y != INF and body.velocity.y == 0.0)
	return body is CharacterBody2D and body.is_on_floor()


func _hold(body: Node) -> void:
	if body == _player:
		_player.velocity = Vector2.ZERO
		_player.state_machine.change_state("IdleState")
		_player.set_process(false)
		_player.set_physics_process(false)
		return
	_frozen_enemies.append([body, body.process_mode])
	body.process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(_delta: float) -> void:
	if not _settling.is_empty() and not _outro:
		_settle()


func is_settled() -> bool:
	return _settling.is_empty()


func skipped() -> bool:
	return _skipped


func camera() -> Camera2D:
	return _cam


func caption() -> CaptionCard:
	return _card
