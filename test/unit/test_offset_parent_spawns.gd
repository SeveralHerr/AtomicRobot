extends RefCounted

## Player report: "power-ups that drop during the boss fight are near the ceiling" and
## "I could see the fireball near the ceiling while rapid firing". The boss room's root
## sits at (19, -251); the street's sits at the origin. A node given its world spot
## BEFORE it joins the tree keeps that number as a LOCAL offset, so under the boss room
## it landed 251 px too high. Every spawner must place a node after add_child (or
## convert with to_local when the add is deferred).

var _T

const MAID := preload("res://scenes/meter_maid_melee.tscn")
const Rig := preload("res://test/unit/player_combat_rig.gd")
## The boss room's root offset (scenes/boss_room.tscn).
const BOSS_ROOM_ROOT := Vector2(19, -251)

var _stage: Node2D
var _old_scene: Node
var _r: Rig


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func setup() -> void:
	_stage = Node2D.new()
	_stage.position = BOSS_ROOM_ROOT
	_tree().root.add_child(_stage)
	_old_scene = _tree().current_scene
	_tree().current_scene = _stage
	_r = Rig.new()


func teardown() -> void:
	_r.free_all()
	_tree().current_scene = _old_scene
	_stage.queue_free()
	await _tree().process_frame


func test_powerup_drop_hovers_over_the_floor_under_an_offset_room() -> String:
	var maid: Node2D = MAID.instantiate()
	_stage.add_child(maid)
	maid.process_mode = Node.PROCESS_MODE_DISABLED
	maid.global_position = Vector2(321, -20)
	var floor_line: float = maid.global_position.y + maid.foot_offset()
	var pickup: Node2D = Utils.drop_powerup(maid, "rage")
	await _tree().process_frame
	var r: String = _T.assert_float_eq(pickup.global_position.x, 321.0, 0.01, "x where the enemy fell")
	if r == "":
		r = _T.assert_float_eq(pickup.global_position.y, floor_line - PowerupPickup.HOVER_HEIGHT, 0.01,
			"hovers HOVER_HEIGHT over the floor, not %d px off" % BOSS_ROOM_ROOT.y)
	return r


## Payton's impact burst flares where the fireball hit, with the room offset.
func test_fireball_burst_appears_at_the_hit_under_an_offset_room() -> String:
	await _r.spawn("Payton")
	_r.world.position = BOSS_ROOM_ROOT
	await _r.step(2)
	var e := _r.maid(60.0)
	var got := []
	_r.world.child_entered_tree.connect(func(n: Node) -> void:
		if n is FireballBullet:
			n.tree_exiting.connect(func() -> void: got.append(["shot", n.sprite.global_position]))
		elif n is AnimatedSprite2D and n.sprite_frames and n.sprite_frames.has_animation("fly"):
			got.append(["puff", n]))
	_r.tap("Attack")
	await _r.until(func(): return e.health < Rig.HP, 60)
	await _r.step(1)
	var shot_at = null
	var puff: Node2D = null
	for g in got:
		if g[0] == "shot":
			shot_at = g[1]
		elif g[0] == "puff":
			puff = g[1]
	if shot_at == null or puff == null:
		return "no shot/burst recorded (%s)" % [got]
	return _T.assert_true(puff.global_position.distance_to(shot_at) < 2.0,
		"burst at %s, fireball hit at %s" % [puff.global_position, shot_at])


## Static guard: no script sets a freshly made node's global_position before it is
## added (or while its add is deferred). Scans scripts/ the way the bug was found.
func test_no_spawner_places_a_node_before_it_is_in_the_tree() -> String:
	var bad: Array[String] = []
	for path in _scripts("res://scripts"):
		var src := FileAccess.get_file_as_string(path)
		for body in _func_bodies(src):
			for m in RegEx.create_from_string("(\\w+)\\.global_position\\s*=").search_all(body):
				var v := m.get_string(1)
				var made := RegEx.create_from_string("\\b" + v + "\\s*(?::\\s*\\w+\\s*)?:?=[^\\n]*(instantiate\\(\\)|\\.new\\()")
				if made.search(body) == null:
					continue
				var add := RegEx.create_from_string("add_child(\\.call_deferred)?\\(\\s*" + v + "\\b").search(body)
				if add != null and (add.get_string(1) != "" or add.get_start() > m.get_start()):
					bad.append("%s: %s" % [path, v])
	return _T.assert_eq(bad, [] as Array[String], "set global_position after add_child")


static func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out


static func _func_bodies(src: String) -> Array[String]:
	var out: Array[String] = []
	var parts := RegEx.create_from_string("\\n(?:static )?func ").search_all(src)
	for i in parts.size():
		var a := parts[i].get_end()
		var b := parts[i + 1].get_start() if i + 1 < parts.size() else src.length()
		out.append(src.substr(a, b - a))
	return out
