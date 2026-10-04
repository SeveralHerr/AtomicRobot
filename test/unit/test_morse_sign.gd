extends RefCounted

# Secret: the Atomic Robot Tattoo shop sign's neon outline blinks ATOMIC in
# International Morse. The on/off timeline is derived from the word + a Morse table,
# so these tests render it back into dots/dashes and decode it, both directions.

var _T

const MORSE := preload("res://scripts/morse_code.gd")
const BUILDING := preload("res://scenes/atomic_robot_building.tscn")
const SHOP := preload("res://images/new/Shop.png")

var _nodes: Array[Node] = []


func teardown() -> void:
	MicroCutscene.playing = false
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


# Dot "." dash "-", letter gap " ", word gap " / " -- the textbook rendering.
func _render(timeline: Array) -> String:
	var s := ""
	for seg in timeline:
		var lit: bool = seg[0]
		var units: int = seg[1]
		if lit:
			s += "." if units == 1 else ("-" if units == 3 else "?")
		elif units == 3:
			s += " "
		elif units == 7:
			s += " /"
		elif units != 1:
			s += "?"
	return s


func test_morse_timeline_spells_atomic() -> String:
	return _T.assert_eq(_render(MORSE.timeline("ATOMIC")), ".- - --- -- .. -.-. /",
		"ATOMIC in International Morse, looping on a word gap")


func test_morse_timeline_standard_unit_counts() -> String:
	# A5 T3 O11 M7 I3 C11 = 40 lit+intra units, 5 letter gaps x3, word gap 7.
	return _T.assert_eq(MORSE.total_units(MORSE.timeline("ATOMIC")), 62,
		"dot1 dash3 intra1 letter3 word7")


func test_morse_table_round_trips_every_letter() -> String:
	var bad := []
	for letter in MORSE.TABLE:
		if MORSE.decode(MORSE.timeline(letter)) != letter:
			bad.append(letter)
	var r: String = _T.assert_eq(bad, [], "every table letter decodes back to itself")
	if r != "":
		return r
	return _T.assert_eq(MORSE.TABLE.size(), 26, "A-Z, no more no less")


func test_morse_lit_at_samples_and_loops() -> String:
	var tl: Array = MORSE.timeline("ATOMIC")
	var got := [MORSE.lit_at(tl, 0.5), MORSE.lit_at(tl, 1.5), MORSE.lit_at(tl, 3.9),
		MORSE.lit_at(tl, 5.5), MORSE.lit_at(tl, 61.5), MORSE.lit_at(tl, 62.5),
		MORSE.lit_at(tl, 63.5), MORSE.lit_at(tl, 1.0), MORSE.lit_at(tl, 2.0)]
	# A = dot(0-1) gap(1-2) dash(2-5) ; letter gap 5-8 ; word gap 55-62 ; loop.
	return _T.assert_eq(got, [true, false, true, false, false, true, false, false, true],
		"dot, gap, dash, letter gap, word gap, loop dot, loop gap, dot end, dash start")


func _neon() -> Node:
	var b := BUILDING.instantiate()
	_nodes.append(b)
	(Engine.get_main_loop() as SceneTree).root.add_child(b)
	return b.get_node("SignNeon")


func test_morse_sign_wired_on_shop_sign() -> String:
	var n := _neon()
	var r: String = _T.assert_eq(n.word, "ATOMIC", "shop sign spells ATOMIC")
	if r != "":
		return r
	return _T.assert_true(n.unit >= 0.18 and n.unit <= 0.25, "unit readable but buzzy: %s" % n.unit)


func test_morse_sign_blinks_between_lit_and_dim() -> String:
	var n := _neon()
	n._process(n.unit * 0.5)          # inside A's dot
	var on_tube: Color = n.tube.modulate
	var on_halo: float = n.halo.modulate.a
	n._process(n.unit * 1.0)          # into the intra-letter gap
	var off_tube: Color = n.tube.modulate
	var off_halo: float = n.halo.modulate.a
	var r: String = _T.assert_gt(on_halo, off_halo + 0.3, "halo glows when lit")
	if r != "":
		return r
	r = _T.assert_gt(on_tube.get_luminance(), off_tube.get_luminance() + 0.2, "tube brighter when lit")
	if r != "":
		return r
	# "Off" is dimmed neon, never vanished: the tube stays drawn.
	return _T.assert_gt(off_tube.a * off_tube.get_luminance(), 0.3, "off tube still visible")


func test_morse_sign_holds_steady_during_cutscene() -> String:
	var n := _neon()
	n._process(n.unit * 1.5)          # dim: in the gap after A's dot
	MicroCutscene.playing = true
	var seen := {}
	for i in 40:
		n._process(n.unit * 0.5)
		seen[[n.halo.modulate.a > 0.3, n.tube.modulate == n.lit_tube]] = true
	return _T.assert_eq(seen.keys(), [[true, true]], "steady lit sign while a cut scene plays")


func test_morse_sign_tube_sits_on_the_painted_outline() -> String:
	# Every tube pixel must land on a near-white outline pixel of the shop art.
	var n := _neon()
	var tube: Sprite2D = n.tube
	var timg: Image = tube.texture.get_image()
	var shop: Image = SHOP.get_image()
	var origin: Vector2 = n.position + tube.position + Vector2(shop.get_size()) / 2.0
	var lit := 0
	var miss := 0
	for y in timg.get_height():
		for x in timg.get_width():
			if timg.get_pixel(x, y).a < 0.5:
				continue
			lit += 1
			var c := shop.get_pixelv(Vector2i(origin) + Vector2i(x, y))
			if c.r < 0.75 or c.g < 0.75 or c.b < 0.75:
				miss += 1
	var r: String = _T.assert_gt(lit, 300, "tube has the outline in it")
	if r != "":
		return r
	return _T.assert_eq(miss, 0, "tube pixels off the painted outline")


func test_morse_sign_off_fades_to_a_dim_glow_not_dark() -> String:
	var n := _neon()
	n.buzz = 0.0
	n._process(n.unit * 0.95)                 # end of A's dot
	n._process(n.unit * 0.1)                  # just into the gap: halo mid-fade
	var fading: float = n.halo.modulate.a
	for i in 10:
		n._process(n.afterglow * 0.2)         # afterglow spent, still in the gap
	var settled: float = n.halo.modulate.a
	var lit: float = n.lit_halo.a
	var r: String = _T.assert_true(fading < lit and fading > settled + 0.05,
		"afterglow: %s between lit %s and settled %s" % [fading, lit, settled])
	if r != "":
		return r
	r = _T.assert_gt(settled, 0.05, "off is dimmed neon, not dead")
	if r != "":
		return r
	return _T.assert_gt(lit * 0.5, settled, "dim glow well under lit")


func test_morse_sign_leaves_the_global_rng_alone() -> String:
	# Autoplay seeds the global RNG; an ambient prop drawing from it every frame
	# reshuffled seeded fights (brain_stop_x, full_run_mortal failed).
	var n := _neon()
	seed(42)
	var want := randf()
	seed(42)
	for i in 20:
		n._process(n.unit * 0.1)
	return _T.assert_eq(randf(), want, "sign buzz must use its own RNG")
