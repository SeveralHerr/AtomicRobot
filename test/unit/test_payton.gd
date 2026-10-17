extends RefCounted

# Payton (new employee, fireball thrower). Set up exactly like the rest of the roster:
# same animation set, same feet line and body centre in the cell (the player's
# hitboxes are shared, so the art must stand where theirs does), a ranged shot like
# Cass's. The fireball must leave his hand at exactly the spot the release art lets go
# of it, on the right frame, with the sound's whoosh on that frame.
# Art checks read the real textures (AtlasTexture.get_image), never stored numbers.

var _T

const Rig := preload("res://test/unit/player_combat_rig.gd")
const SELECT := preload("res://scripts/character_select.gd")
const Probe := preload("res://test/unit/sprite_probe.gd")
const CELL := 128
## Cass is the 128 px reference sheet (same grid as Payton's).
const REFERENCE := "Cass"

var _r: Rig


func setup() -> void:
	_r = Rig.new()


func teardown() -> void:
	_r.free_all()


func _frames(c: String) -> SpriteFrames:
	return Probe.frames(c)


func _img(c: String, anim: String, i: int) -> Image:
	return Probe.img(c, anim, i)


func _stance(img: Image) -> Vector2:
	return Probe.stance(img)


## Orange/yellow flame (not the white-hot core: skin is bright too).
static func _is_fire(c: Color) -> bool:
	return c.a > 0.0 and c.r > 0.78 and c.g > 0.35 and c.b < 0.47


static func _fire_count(img: Image) -> int:
	return Probe.count(img, _is_fire)


## Centre of the fireball's leading blob (fire px within 12 of the rightmost, above
## y 70 so the release frame's under-swirl doesn't count), in cell px.
static func _fire_head(img: Image) -> Vector2:
	var right := -1
	for y in 70:
		for x in img.get_width():
			if _is_fire(img.get_pixel(x, y)):
				right = maxi(right, x)
	var sum := Vector2.ZERO
	var n := 0
	for y in 70:
		for x in range(maxi(right - 11, 0), right + 1):
			if _is_fire(img.get_pixel(x, y)):
				sum += Vector2(x, y)
				n += 1
	return sum / maxf(n, 1)


# --- roster setup -----------------------------------------------------------------

## Both directions: a fighter missing from the select strip, or a stale card, fails.
func test_every_fighter_is_on_the_select_roster() -> String:
	for c in Globals.character_dict:
		if not SELECT.ROSTER.has(c):
			return "%s is in character_dict but not on the select roster" % c
	for c in SELECT.ROSTER:
		if not Globals.character_dict.has(c):
			return "select card %s has no CharacterConfig" % c
	return _T.assert_eq(SELECT.TICK_STEPS.size(), SELECT.ROSTER.size(), "one tick note per card")


## Every fighter plays the reference set of animations with its loop flags: a missing
## Climb or a looping Dead breaks the player state machine for that one fighter.
func test_every_fighter_has_the_reference_animation_set() -> String:
	var ref := _frames(REFERENCE)
	for c in Globals.character_dict:
		var sf := _frames(c)
		for anim in ref.get_animation_names():
			if not sf.has_animation(anim):
				return "%s has no %s animation" % [c, anim]
			if sf.get_animation_loop(anim) != ref.get_animation_loop(anim) and anim != "Crouch":
				return "%s %s loop=%s, roster loop=%s" % [c, anim, sf.get_animation_loop(anim), ref.get_animation_loop(anim)]
	return ""


func test_payton_matches_the_reference_speeds() -> String:
	var ref := _frames(REFERENCE)
	for anim in ref.get_animation_names():
		var r: String = _T.assert_float_eq(_frames("Payton").get_animation_speed(anim),
			ref.get_animation_speed(anim), 0.01, "Payton %s fps" % anim)
		if r != "":
			return r
	return ""


func test_payton_is_a_ranged_fighter() -> String:
	var cfg: CharacterConfig = Globals.character_dict["Payton"]
	var cass: CharacterConfig = Globals.character_dict["Cass"]
	var r: String = _T.assert_true(cfg.is_ranged() and cfg.unlocked, "ranged and playable")
	if r != "":
		return r
	r = _T.assert_eq(cfg.get_starting_health(), cass.get_starting_health(), "ranged health trade, as Cass")
	if r != "":
		return r
	return _T.assert_eq(cfg.get_weapon_sound().resource_path, "res://sounds/fireball.wav", "fireball sound")


## The player's collision and hit area are shared, so every standing frame must put
## the feet on the reference line and the legs over the body centre like Cass's do.
func test_payton_stands_where_the_roster_stands() -> String:
	var ref := _stance(_img(REFERENCE, "Walk", 0))
	for anim in ["idle", "Walk", "Attack", "Crouch"]:
		for i in _frames("Payton").get_frame_count(anim):
			var s := _stance(_img("Payton", anim, i))
			if absf(s.y - ref.y) > 1.0:
				return "Payton %s[%d] feet at y %d, roster stands at %d" % [anim, i, s.y, ref.y]
			if absf(s.x - CELL / 2.0) > 6.0:
				return "Payton %s[%d] legs centred at x %.0f, cell centre %d" % [anim, i, s.x, CELL / 2]
	return ""


## Every fighter breathes: an idle of 2+ frames whose feet stay planted while the body
## moves (a 1-frame idle stands frozen while the rest of the roster bobs).
func test_every_fighter_has_a_breathing_idle() -> String:
	for c in Globals.character_dict:
		var n := _frames(c).get_frame_count("idle")
		if n < 2:
			return "%s idle has %d frame(s): stands frozen" % [c, n]
		var first := _img(c, "idle", 0)
		var moved := false
		for i in range(1, n):
			var img := _img(c, "idle", i)
			if absf(_stance(img).y - _stance(first).y) > 2.0:
				return "%s idle[%d] feet move %d px" % [c, i, _stance(img).y - _stance(first).y]
			moved = moved or img.get_data() != first.get_data()
		if not moved:
			return "%s idle frames are all identical" % c
	return ""


## Walk loops: no frame-to-frame (or last-to-first) jump in the legs bigger than a
## normal step, so the run cycle doesn't hitch at the wrap.
func test_payton_walk_cycle_loops_without_a_hitch() -> String:
	var n := _frames("Payton").get_frame_count("Walk")
	for i in n:
		var a := _stance(_img("Payton", "Walk", i))
		var b := _stance(_img("Payton", "Walk", (i + 1) % n))
		if absf(a.x - b.x) > 6.0 or absf(a.y - b.y) > 1.0:
			return "Walk %d->%d legs jump %s" % [i, (i + 1) % n, b - a]
	return ""


# --- the fireball hand-off ----------------------------------------------------------

## The art holds the fireball up to the frame before attack_frame (the release swoosh)
## and is empty-handed from attack_frame on: the shot spawns as the art lets go.
func test_attack_frame_is_the_first_empty_handed_frame() -> String:
	var hit: int = Globals.character_dict["Payton"].get_attack_frame()
	var n := _frames("Payton").get_frame_count("Attack")
	for i in n:
		var fire := _fire_count(_img("Payton", "Attack", i))
		if i < hit and fire < 10:
			return "Attack[%d] (before release) shows no fireball" % i
		if i >= hit and fire > 0:
			return "Attack[%d] (after release) still draws %d fire px" % [i, fire]
	return ""


func _first_shot(facing: int) -> Dictionary:
	await _r.spawn("Payton")
	if facing < 0:
		_r.p._handle_direction(-1)
	var got := {}
	_r.world.child_entered_tree.connect(func(n: Node) -> void:
		if n is FireballBullet and got.is_empty():
			got["shot"] = n
			got["frame"] = _r.p.default_sprite.frame)
	_r.tap("Attack")
	await _r.until(func(): return not got.is_empty(), 60)
	await _r.step(1)
	return got


func _check_spawn_spot(facing: int) -> String:
	var got := await _first_shot(facing)
	if got.is_empty():
		return "Payton threw no fireball"
	var shot: FireballBullet = got["shot"]
	var hit: int = Globals.character_dict["Payton"].get_attack_frame()
	var r: String = _T.assert_eq(got["frame"], hit, "spawns on the attack frame")
	if r != "":
		return r
	r = _T.assert_eq(int(shot.scale.x), facing, "fireball art faces its flight")
	if r != "":
		return r
	# Where the release art's fireball head was, in the world.
	var sprite := _r.p.default_sprite
	var swoosh := _fire_head(_img("Payton", "Attack", hit - 1)) - Vector2(CELL, CELL) / 2.0
	var want := sprite.global_transform * (swoosh + sprite.offset)
	# Where the fireball's own head was at spawn (undo the travel since).
	var fs := shot.sprite
	var tex := fs.sprite_frames.get_frame_texture(fs.animation, fs.frame)
	var head := _fire_head(tex.get_image()) - tex.get_size() / 2.0
	var spawn_shift := Vector2(shot.dir * shot._travelled, 0.0)
	var have := fs.global_transform * (head + fs.offset) - spawn_shift
	return _T.assert_true(have.distance_to(want) <= 2.0,
		"fireball head spawns at %s, release art's head at %s (facing %d)" % [have, want, facing])


func test_fireball_leaves_the_hand_at_the_release_art_facing_right() -> String:
	return await _check_spawn_spot(1)


func test_fireball_leaves_the_hand_at_the_release_art_facing_left() -> String:
	return await _check_spawn_spot(-1)


## The hand is ~50 px forward of the body: a maid between body and hand still gets hit.
func test_point_blank_maid_is_hit() -> String:
	await _r.spawn("Payton")
	var e := _r.maid(18.0)
	_r.tap("Attack")
	await _r.until(func(): return e.health < Rig.HP, 60)
	return _T.assert_true(e.health < Rig.HP, "fireball hits a maid 18 px in front")


func test_maid_behind_is_not_hit() -> String:
	await _r.spawn("Payton")
	var e := _r.maid(-24.0)
	_r.tap("Attack")
	await _r.until(func(): return _r.state_name() != "AttackState", 90)
	return _T.assert_eq(e.health, Rig.HP, "nothing hits a maid behind him")


func test_fireball_knocks_back_like_the_flipflop() -> String:
	var f: FireballBullet = load("res://scenes/fireball_bullet.tscn").instantiate()
	var r: String = _T.assert_float_eq(f.knockback, FlipflopBullet.KNOCKBACK, 0.01, "slide-back")
	if r == "":
		r = _T.assert_float_eq(f.speed, FlipflopBullet.FLIPFLOP_SPEED, 0.01, "speed")
	f.free()
	return r


# --- the sound ----------------------------------------------------------------------

## 16-bit PCM samples (first channel) and rate from a RIFF .wav (the imported stream
## is QOA-compressed, so its `data` isn't PCM).
static func _read_wav(path: String) -> Dictionary:
	var b := FileAccess.get_file_as_bytes(path)
	var i := 12
	var ch := 1
	var rate := 0
	while i + 8 <= b.size():
		var id := b.slice(i, i + 4).get_string_from_ascii()
		var n := b.decode_u32(i + 4)
		if id == "fmt ":
			ch = b.decode_u16(i + 10)
			rate = b.decode_u32(i + 12)
		elif id == "data":
			var out := PackedFloat32Array()
			for k in range(i + 8, i + 8 + n - 1, 2 * ch):
				out.append(b.decode_s16(k) / 32768.0)
			return {"rate": rate, "pcm": out}
		i += 8 + n + (n & 1)
	return {}


## The weapon sound starts on swing frame 0; its loudest 10 ms must land on the
## release (attack_frame at the Attack playback rate), not before or long after.
func test_fireball_whoosh_peaks_on_the_release_frame() -> String:
	var path: String = Globals.character_dict["Payton"].get_weapon_sound().resource_path
	var wav := _read_wav(path)
	if wav.is_empty():
		return "no PCM data in %s" % path
	var pcm: PackedFloat32Array = wav["pcm"]
	var win := int(wav["rate"] * 0.01)
	var best := -1.0
	var best_t := 0.0
	for i in range(0, pcm.size() - win, win):
		var e := 0.0
		for k in win:
			e += pcm[i + k] * pcm[i + k]
		if e > best:
			best = e
			best_t = float(i) / wav["rate"]
	var fps := _frames("Payton").get_animation_speed("Attack") * AttackChain.ANIM_SPEED
	var release := Globals.character_dict["Payton"].get_attack_frame() / fps
	return _T.assert_float_eq(best_t, release, 0.02, "whoosh peak at %.3fs, release at %.3fs" % [best_t, release])


## Out of range it burns out (no blink-off) and can't hit anything while it does.
func test_fireball_fizzles_out_at_max_range() -> String:
	var f: FireballBullet = load("res://scenes/fireball_bullet.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(f)
	f.dir = -1
	f._travelled = LaneProjectile.MAX_TRAVEL
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame
	var r: String = _T.assert_false(f.is_physics_processing(), "stopped: no more hit sweeps")
	if r == "":
		r = _T.assert_eq(int(f.scale.x), -1, "still faces its flight while it fizzles")
	if r == "":
		r = _T.assert_true(is_instance_valid(f) and f.sprite.modulate.a < 1.0, "fading, not blinked off")
	await (Engine.get_main_loop() as SceneTree).create_timer(FireballBullet.FIZZLE_TIME + 0.1).timeout
	if r == "":
		r = _T.assert_false(is_instance_valid(f), "freed after the fizzle")
	if is_instance_valid(f):
		f.free()
	return r


## A hit leaves a flame puff at the impact that burns out on its own.
func test_fireball_hit_leaves_a_burst_that_cleans_up() -> String:
	await _r.spawn("Payton")
	var e := _r.maid(60.0)
	var puffs := []
	_r.world.child_entered_tree.connect(func(n: Node) -> void:
		if n is AnimatedSprite2D and n.sprite_frames and n.sprite_frames.has_animation("fly"):
			puffs.append(n))
	_r.tap("Attack")
	await _r.until(func(): return e.health < Rig.HP, 60)
	var r: String = _T.assert_eq(puffs.size(), 1, "one burst at the impact")
	if r != "":
		return r
	await _r.tree().create_timer(FireballBullet.FIZZLE_TIME + 0.15).timeout
	return _T.assert_false(is_instance_valid(puffs[0]), "burst freed itself")
