extends RefCounted

# The look of a BuildingDoorEncounter's mouth (DoorMouthFx: WallMouth / BushMouth)
# and where each street placement sits. Lifecycle/timing lives in
# test_door_encounter.gd; these pin what the player sees.

var _T

const ENC_SCENE := preload("res://scenes/building_door_encounter.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var _stage: Node2D


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func teardown() -> void:
	if _stage != null:
		_stage.free()
		_stage = null


func _make(style: int) -> Node:
	_stage = Node2D.new()
	_tree().root.add_child(_stage)
	var enc = ENC_SCENE.instantiate()
	enc.mouth_style = style
	_stage.add_child(enc)
	return enc


func _wait(seconds: float) -> void:
	await _tree().create_timer(seconds).timeout


# --- wall ---------------------------------------------------------------------

func test_wall_closed_shows_only_the_hairline_crack() -> String:
	var enc = _make(DoorMouthFx.Style.WALL)
	var m: WallMouth = enc.mouth
	var r: String = _T.assert_true(enc.crack.visible and enc.crack.frame == 0, "hairline tell")
	if r != "":
		return r
	return _T.assert_false(m.breach.visible or m.rubble.visible, "no hole before the burst")


func test_wall_burst_swaps_the_crack_for_a_breach_with_rubble() -> String:
	var enc = _make(DoorMouthFx.Style.WALL)
	var m: WallMouth = enc.mouth
	m.burst()
	var r: String = _T.assert_true(m.is_open(), "open")
	if r != "":
		return r
	r = _T.assert_false(enc.crack.visible, "the splat sprite no longer stands in for the hole")
	if r != "":
		return r
	return _T.assert_true(m.breach.visible and m.rubble.visible, "breach + rubble on the sidewalk")


func test_wall_breach_takes_the_wall_colour() -> String:
	_stage = Node2D.new()
	_tree().root.add_child(_stage)
	var enc = ENC_SCENE.instantiate()
	enc.wall_color = Color(0.3, 0.2, 0.1)
	_stage.add_child(enc)
	var m: WallMouth = enc.mouth
	# The sheet's 128 grey is the wall itself, so the rim is modulated by 2x the wall.
	return _T.assert_true(m.rim.modulate.is_equal_approx(Color(0.6, 0.4, 0.2, 1.0)), "rim tint %s" % m.rim.modulate)


func test_wall_telegraph_widens_the_crack_and_sheds_grit() -> String:
	var enc = _make(DoorMouthFx.Style.WALL)
	var m: WallMouth = enc.mouth
	m.telegraph(true, 0.1)
	var r: String = _T.assert_true(m.trickle.emitting, "grit trickles during the rumble")
	if r != "":
		return r
	await _wait(0.2)
	return _T.assert_eq(enc.crack.frame, WallMouth.CRACK_WIDEST_FRAME, "crack at its widest")


func test_wall_stop_mid_telegraph_settles_the_crack() -> String:
	var enc = _make(DoorMouthFx.Style.WALL)
	var m: WallMouth = enc.mouth
	var home: Vector2 = enc.crack.position
	m.telegraph(true, 0.6)
	var moved := false
	for i in 30:
		await _tree().process_frame
		if enc.crack.position != home:
			moved = true
			break
	if not moved:
		return "the crack never twitched during the rumble"
	m.stop()
	await _wait(0.05)
	var r: String = _T.assert_eq(enc.crack.position, home, "jitter undone")
	if r != "":
		return r
	return _T.assert_false(m.trickle.emitting or m.is_open(), "quiet and still closed")


# --- bush ---------------------------------------------------------------------

func test_bush_hides_the_crack_in_the_foliage() -> String:
	var enc = _make(DoorMouthFx.Style.BUSH)
	var m: BushMouth = enc.mouth
	var r: String = _T.assert_true(enc.mouth is BushMouth, "a BUSH placement builds a shrub mouth")
	if r != "":
		return r
	r = _T.assert_false(enc.crack.visible, "no wall crack painted on a hedge")
	if r != "":
		return r
	return _T.assert_true(m.clump.visible and not m.hollow.visible, "a whole shrub until it bursts")


func test_bush_telegraph_shakes_and_peeks() -> String:
	var enc = _make(DoorMouthFx.Style.BUSH)
	var m: BushMouth = enc.mouth
	m.telegraph(true, 0.2)
	await _wait(0.1)
	var r: String = _T.assert_true(m.shed.emitting, "leaves shed")
	if r != "":
		return r
	r = _T.assert_true(m.eyes.visible, "eyes peek out of the bush")
	if r != "":
		return r
	return _T.assert_true(absf(m.clump.skew) > 0.0 or m.clump.scale != Vector2.ONE, "the shrub moves")


func test_bush_burst_parts_the_shrub_outward() -> String:
	var enc = _make(DoorMouthFx.Style.BUSH)
	var m: BushMouth = enc.mouth
	m.burst()
	await _wait(0.6)
	var r: String = _T.assert_true(m.hollow.visible and not m.clump.visible, "a dark gap where the shrub was")
	if r != "":
		return r
	var gap: float = m.right_half.position.x - m.left_half.position.x - BushMouth.FRAME.x * 0.8
	r = _T.assert_true(m.left_half.rotation < -0.1 and m.right_half.rotation > 0.1 and gap > 12.0,
		"halves part (rot %.2f / %.2f, gap %.0f px)" % [m.left_half.rotation, m.right_half.rotation, gap])
	if r != "":
		return r
	return _T.assert_true(m.litter.visible and not m.eyes.visible, "leaves litter the walk")


func test_bush_halves_rebuild_the_shrub_exactly() -> String:
	var enc = _make(DoorMouthFx.Style.BUSH)
	var m: BushMouth = enc.mouth
	# Unrotated, each half must sit exactly where the whole clump is drawn.
	var want: Vector2 = m.clump.position + m.clump.offset
	for half in [m.left_half, m.right_half]:
		var at: Vector2 = half.position + half.offset
		if not at.is_equal_approx(want):
			return "half drawn at %s, want %s" % [at, want]
	var l: Image = m.left_half.texture.get_image()
	var r: Image = m.right_half.texture.get_image()
	var c: Image = m.clump.texture.get_image()
	for y in c.get_height():
		for x in c.get_width():
			var a := l.get_pixel(x, y).a + r.get_pixel(x, y).a
			if absf(a - c.get_pixel(x, y).a) > 0.01:
				return "halves leave a hole/overlap at (%d, %d)" % [x, y]
	return ""


# --- placements -----------------------------------------------------------------

## Encounter x (world) -> style, decided by looking at what is behind each mouth.
const STYLES := {389: "WALL", 2361: "WALL", 4721: "WALL", 5492: "BUSH", 6080: "BUSH", 6949: "BUSH", 7775: "BUSH"}


func _world_x(n: Node) -> float:
	var x := 0.0
	while n != null:
		if n is Node2D:
			x += n.position.x
		n = n.get_parent()
	return x


func _street() -> Array:
	var main := MAIN_SCENE.instantiate()
	var found: Array = []
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_method("lane_for_index"):
			found.append(n)
		stack.append_array(n.get_children())
	_stage = Node2D.new()
	_stage.add_child(main)
	return found


func test_every_street_mouth_has_its_chosen_style() -> String:
	var encs := _street()
	var seen := {}
	for e in encs:
		var x := int(round(_world_x(e)))
		var key := -1
		for k in STYLES:
			if absi(k - x) < 120:
				key = k
		if key < 0:
			return "unplaced encounter at x=%d" % x
		seen[key] = true
		var style: String = DoorMouthFx.Style.keys()[e.mouth_style]
		if style != STYLES[key]:
			return "encounter at x=%d is %s, want %s" % [x, style, STYLES[key]]
	return _T.assert_eq(seen.size(), STYLES.size(), "every placement accounted for")


func test_dimmed_hedges_get_dimmed_shrubs() -> String:
	# The Bush sprites behind 5492 and 7775 are modulated 0.73; a full-bright shrub
	# in front of them would read as a pasted-on sticker.
	for e in _street():
		var x := int(round(_world_x(e)))
		if absi(x - 5492) < 120 or absi(x - 7775) < 120:
			if not is_equal_approx(e.foliage_shade, 0.73):
				return "x=%d foliage_shade %.2f" % [x, e.foliage_shade]
	return ""
