extends RefCounted

# Cass's throw. Player feedback: "Cass animation/projectile isn't as fluid as Payton's".
# The shot used to spawn on Attack frame 3 at the shared Robot marker while her art still
# held the flip-flop behind her head on frames 3 and 4: two flip-flops on screen, and
# the thrown one popped in at her chest. It now leaves her open hand on the first
# empty-handed frame, the wind-up plays faster so it still leaves at the old time (her
# ranged balance was tuned on that), and it tumbles out / ricochets instead of blinking off.
# Art checks read the real textures (sprite_probe.gd), never stored numbers.

var _T

const Rig := preload("res://test/unit/player_combat_rig.gd")
const Probe := preload("res://test/unit/sprite_probe.gd")
const FLIPFLOP := preload("res://scenes/flipflop_bullet.tscn")
const CELL := 128
## Her shot left on frame 3 of a uniform 15 fps Attack before this fix: keep that time.
const TUNED_RELEASE_UNITS := 3.0
## Old mashed-chain point: hit frame 3 + AttackChain.RECOVERY_FRAMES, uniform frames.
const TUNED_CHAIN_UNITS := 5.0

var _r: Rig


func setup() -> void:
	_r = Rig.new()


func teardown() -> void:
	_r.free_all()


## The flip-flop's red rubber (her plaid, skin and hair never pass).
static func _is_flipflop(c: Color) -> bool:
	return c.a > 0.0 and c.r > 0.43 and c.r > c.g * 1.8 and c.r > c.b * 1.8


static func _is_skin(c: Color) -> bool:
	return c.a > 0.0 and c.r > 0.78 and c.g > 0.55 and c.g < 0.84 and c.b > 0.39 and c.b < 0.75 and c.r > c.b + 0.16


func _hit_frame() -> int:
	return Globals.character_dict["Cass"].get_attack_frame()


func _units_before(frame: int) -> float:
	var t := 0.0
	for i in frame:
		t += Probe.frames("Cass").get_frame_duration("Attack", i)
	return t


# --- the hand-off -------------------------------------------------------------------

## Her art holds the flip-flop up to the frame before attack_frame and is empty-handed
## from attack_frame on, so the thrown one is never on screen twice.
func test_shot_spawns_on_the_first_empty_handed_frame() -> String:
	var n := Probe.frames("Cass").get_frame_count("Attack")
	for i in n:
		var red := Probe.count(Probe.img("Cass", "Attack", i), _is_flipflop)
		if i < _hit_frame() and red < 60:
			return "Attack[%d] (before release) shows no flip-flop (%d px)" % [i, red]
		if i == _hit_frame() and red > 20:
			return "Attack[%d] (release) still draws the flip-flop (%d px)" % [i, red]
	return ""


## Balance-neutral: the wind-up plays faster, so the shot leaves at the old time and a
## mashed string chains at the old time.
func test_release_and_chain_keep_the_tuned_timing() -> String:
	var r: String = _T.assert_float_eq(_units_before(_hit_frame()), TUNED_RELEASE_UNITS, 0.01,
		"frame-units before the release")
	if r != "":
		return r
	return _T.assert_float_eq(_units_before(_hit_frame() + AttackChain.RECOVERY_FRAMES),
		TUNED_CHAIN_UNITS, 0.01, "frame-units before a mashed swing can chain")


## Every swing frame shows for at least one 60 Hz frame, so none is skipped.
func test_every_attack_frame_gets_screen_time() -> String:
	var sf := Probe.frames("Cass")
	var fps := sf.get_animation_speed("Attack") * AttackChain.ANIM_SPEED
	for i in sf.get_frame_count("Attack"):
		var shown := sf.get_frame_duration("Attack", i) / fps
		if shown < 1.0 / 60.0:
			return "Attack[%d] shows %.1f ms, under one 60 Hz frame" % [i, shown * 1000.0]
	return ""


func _first_shot(facing: int) -> Dictionary:
	await _r.spawn("Cass")
	if facing < 0:
		_r.p._handle_direction(-1)
	var got := {}
	_r.world.child_entered_tree.connect(func(n: Node) -> void:
		if n is FlipflopBullet and got.is_empty():
			got["shot"] = n
			got["frame"] = _r.p.default_sprite.frame)
	_r.tap("Attack")
	await _r.until(func(): return not got.is_empty(), 60)
	await _r.step(1)
	return got


## The flip-flop's trailing edge sits on her fingertips in the release frame.
func _check_leaves_the_hand(facing: int) -> String:
	var got := await _first_shot(facing)
	if got.is_empty():
		return "Cass threw nothing"
	var r: String = _T.assert_eq(got["frame"], _hit_frame(), "spawns on the attack frame")
	if r != "":
		return r
	var shot: FlipflopBullet = got["shot"]
	var sprite := _r.p.default_sprite
	var hand_img := Probe.img("Cass", "Attack", _hit_frame())
	var tip := Probe.rightmost(hand_img, _is_skin)
	var want := Probe.to_world(sprite, tip, hand_img.get_size(), sprite.offset)
	# The flip-flop's back edge at spawn (unrotated then; undo the travel since). It is
	# never mirrored: the art is symmetric and spins.
	var ff: Sprite2D = shot.get_node("Sprite2D")
	var box := Probe.bbox(ff.texture.get_image())
	var spawn_pos := shot.global_position - Vector2(shot.dir * shot._travelled, 0.0)
	var centre := spawn_pos + ff.position + box.get_center() - Vector2(CELL, CELL) / 2.0
	var back := centre - Vector2(facing * box.size.x / 2.0, 0.0)
	return _T.assert_true(absf(back.x - want.x) <= 3.0 and absf(back.y - want.y) <= 4.0,
		"flip-flop back edge at %s, fingertips at %s (facing %d)" % [back, want, facing])


func test_flipflop_leaves_her_hand_facing_right() -> String:
	return await _check_leaves_the_hand(1)


func test_flipflop_leaves_her_hand_facing_left() -> String:
	return await _check_leaves_the_hand(-1)


## Her hand is ~50 px forward too: a maid between body and hand still gets hit.
func test_point_blank_maid_is_hit_by_cass() -> String:
	await _r.spawn("Cass")
	var e := _r.maid(18.0)
	_r.tap("Attack")
	await _r.until(func(): return e.health < Rig.HP, 60)
	return _T.assert_true(e.health < Rig.HP, "flip-flop hits a maid 18 px in front")


# --- the ending ---------------------------------------------------------------------

## Out of range it tumbles down and fades (still spinning) instead of blinking off.
func test_flipflop_tumbles_out_at_max_range() -> String:
	var f: FlipflopBullet = FLIPFLOP.instantiate()
	_r.add(f)
	f.global_position = Vector2(100, 100)
	f.dir = 1
	f._travelled = LaneProjectile.MAX_TRAVEL
	await _r.step(2)
	var r: String = _T.assert_false(f.is_physics_processing(), "stopped: no more hit sweeps")
	if r == "":
		r = _T.assert_true(f.modulate.a < 1.0, "fading, not blinked off")
	var rot := f.rotation
	await _r.step(2)
	if r == "":
		r = _T.assert_true(is_instance_valid(f) and f.rotation != rot, "still spinning as it drops")
	await _r.tree().create_timer(FlipflopBullet.TUMBLE_TIME + 0.1).timeout
	if r == "":
		r = _T.assert_false(is_instance_valid(f), "freed after the tumble")
	return r


## A hit knocks the flip-flop back up off the maid (a spinning ricochet that cleans up).
func test_flipflop_ricochets_off_a_hit() -> String:
	await _r.spawn("Cass")
	var e := _r.maid(60.0)
	var bounces := []
	_r.world.child_entered_tree.connect(func(n: Node) -> void:
		if n is Sprite2D and n.has_meta("ricochet"):
			bounces.append(n))
	_r.tap("Attack")
	await _r.until(func(): return e.health < Rig.HP, 60)
	var r: String = _T.assert_eq(bounces.size(), 1, "one ricochet at the impact")
	if r != "":
		return r
	var start: Vector2 = bounces[0].global_position
	await _r.step(3)
	r = _T.assert_true(bounces[0].global_position.y < start.y, "pops up off the maid")
	if r != "":
		return r
	await _r.tree().create_timer(FlipflopBullet.TUMBLE_TIME + 0.2).timeout
	return _T.assert_false(is_instance_valid(bounces[0]), "ricochet freed itself")


## Overhand: tips forward the way it flies (clockwise right, counter-clockwise left).
func test_flipflop_spins_forward_both_ways() -> String:
	for d in [1, -1]:
		var f: FlipflopBullet = FLIPFLOP.instantiate()
		_r.add(f)
		f.dir = d
		await _r.step(3)
		var spun := f.rotation
		f.free()
		var r: String = _T.assert_eq(int(signf(spun)), d, "dir %d spins %s" % [d, spun])
		if r != "":
			return r
	return ""
