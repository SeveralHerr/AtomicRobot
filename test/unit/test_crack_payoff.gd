extends RefCounted

# Secret wall payoff (scripts/crack.gd + scripts/secret_fx.gd): chunks, a gold
# "SECRET!" on the opening blow, the orb waiting in the hole, its flight to the HP
# bar, and Globals.secret_found("wall", path) — once.

var _T

const CRACK_SCENE := preload("res://scenes/crack.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _nodes: Array[Node] = []
var _found: Array = []


func setup() -> void:
	ComicPopup.reset_rate_limits()
	_found.clear()
	Globals.secret_found.connect(_on_secret)


func teardown() -> void:
	Globals.secret_found.disconnect(_on_secret)
	var live := ComicPopup.live()
	if live != null:
		live.free()
	ComicPopup.reset_rate_limits()
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _on_secret(kind: String, id: String) -> void:
	_found.append([kind, id])


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _add(n: Node) -> Node:
	_tree().root.add_child(n)
	_nodes.append(n)
	return n


func _crack() -> Crack:
	var c: Crack = _add(CRACK_SCENE.instantiate())
	c.global_position = Vector2(400, 300)
	return c


func _attacker() -> Node2D:
	var a := Node2D.new()
	_add(a)
	a.global_position = Vector2(440, 300)
	return a


func _open(c: Crack) -> void:
	var a := _attacker()
	for i in 5:
		ComicPopup.reset_rate_limits()
		c.take_blow(a)


func test_blow_pops_smash_and_opening_blow_pops_secret() -> String:
	var c := _crack()
	var a := _attacker()
	c.take_blow(a)
	var live := ComicPopup.live()
	var r: String = _T.assert_true(live != null and live.word in ComicPopup.KINDS[&"smash"]["words"],
		"a chip pops a smash word")
	if r != "":
		return r
	for i in 4:
		ComicPopup.reset_rate_limits()
		c.take_blow(a)
	live = ComicPopup.live()
	r = _T.assert_true(live != null and live.word == "SECRET!", "the opening blow says SECRET!")
	if r != "":
		return r
	return _T.assert_eq(live.style, &"gold", "in gold")


func test_blows_on_an_open_wall_do_nothing() -> String:
	var c := _crack()
	_open(c)
	ComicPopup.reset_rate_limits()  # also forgets the live word
	c.take_blow(_attacker())
	return _T.assert_eq(ComicPopup.live(), null, "no new word over an open hole")


func test_opening_leaves_an_orb_in_the_hole_and_paints_it() -> String:
	var c := _crack()
	_open(c)
	var r: String = _T.assert_eq(c.find_children("*", "Sprite2D", false, false).size(), 1, "orb waits in the hole")
	if r != "":
		return r
	r = _T.assert_true(c.animated_sprite_2d.material is ShaderMaterial, "hole interior painted")
	if r != "":
		return r
	return _T.assert_gt(c.find_children("*", "CPUParticles2D", false, false).size(), 0, "brick chunks fly")


func test_claim_reports_one_wall_secret() -> String:
	var c := _crack()
	_open(c)
	c.claim()
	c.claim()
	var r: String = _T.assert_eq(_found, [["wall", str(c.get_path())]], "one wall secret, id = path")
	if r != "":
		return r
	await _tree().process_frame
	return _T.assert_eq(c.find_children("*", "Sprite2D", true, false).size(), 1,
		"the hole orb became the flying orb")


func test_claim_before_open_does_nothing() -> String:
	var c := _crack()
	c.take_blow(_attacker())
	c.claim()
	return _T.assert_eq(_found.size(), 0, "nothing to claim yet")


func test_orb_heals_on_arrival_not_before() -> String:
	var p: Player = _add(PLAYER_SCENE.instantiate())
	p.set_process(false)
	p.set_physics_process(false)
	p.health = Player.HITS_PER_ORB
	var c := _crack()
	_open(c)
	c.claim()
	var r: String = _T.assert_eq(p.health, Player.HITS_PER_ORB, "still flying")
	if r != "":
		return r
	await _tree().create_timer(SecretFx.FLIGHT + 0.3).timeout
	return _T.assert_eq(p.health, 2 * Player.HITS_PER_ORB, "landed in the HP bar")


## Smash/secret words sit on brick: a half-faded card went muddy and unreadable on
## it, so they leave by shrinking at full opacity instead.
func test_wall_words_never_go_translucent() -> String:
	for kind: StringName in [&"smash", &"secret"]:
		var p := ComicPopup.new()
		var cfg: Dictionary = ComicPopup.KINDS[kind]
		p.anim = cfg["anim"]
		p.exit = cfg.get("exit", &"fade")
		p.life = cfg["life"]
		p.size_mult = cfg["size"]
		p._apply(p.life - 0.05)
		var a := p.modulate.a
		var s := p.scale.x
		p.free()
		if a < 1.0:
			return "%s alpha %.2f near its end" % [kind, a]
		if s > ComicPopup.BASE_SCALE * float(cfg["size"]) * 0.5:
			return "%s still full size (%.3f) near its end" % [kind, s]
	return ""
