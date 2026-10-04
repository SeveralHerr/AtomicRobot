extends RefCounted

## Every collectible reads the same way: a PowerupGlow (halo + sparkles) behind it,
## and a scale-up burst when collected. Before this, only placed power-ups and the
## roof heart sparkled; dropped power-ups, the other level hearts and the door/boss
## hearts were plain, and hearts just vanished on pickup.
##
## The heart list is derived from the levels (every instance of the heart scene),
## not hand-typed, so a newly placed heart is covered automatically.

var _T

const HEART := "res://scenes/atomic_heart_pickup.tscn"
const PICKUP := preload("res://scenes/powerup_pickup.tscn")
const LEVELS := ["res://scenes/main.tscn", "res://scenes/boss_room.tscn"]

var _stage: Node2D


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func setup() -> void:
	_stage = Node2D.new()
	_tree().root.add_child(_stage)


func teardown() -> void:
	_stage.queue_free()
	await _tree().process_frame


static func _glows(n: Node) -> int:
	var count := 0
	for c in n.get_children():
		if c is PowerupGlow:
			count += 1
	return count


static func _collect(n: Node, path: String, out: Array) -> void:
	if n.scene_file_path == path:
		out.append(n)
	for c in n.get_children():
		_collect(c, path, out)


func test_every_level_heart_has_exactly_one_glow() -> String:
	var checked := 0
	for level_path in LEVELS:
		var level: Node = (load(level_path) as PackedScene).instantiate()
		var hearts: Array = []
		_collect(level, HEART, hearts)
		for h in hearts:
			checked += 1
			if _glows(h) != 1:
				var msg := "%s: %s has %d glows" % [level_path, level.get_path_to(h), _glows(h)]
				level.free()
				return _T.assert_true(false, msg)
		level.free()
	return _T.assert_gt(checked, 3, "found the level hearts")


func test_runtime_heart_has_a_glow() -> String:
	# Door encounter and boss room instantiate the bare scene.
	var heart: Node = (load(HEART) as PackedScene).instantiate()
	var n := _glows(heart)
	heart.free()
	return _T.assert_eq(n, 1, "bare heart scene glows")


func test_dropped_and_placed_powerups_both_glow() -> String:
	for placed in [false, true]:
		var p: Node2D = PICKUP.instantiate()
		p.set("placed", placed)
		_stage.add_child(p)
		if _glows(p) != 1:
			return _T.assert_true(false, "placed=%s pickup has %d glows" % [placed, _glows(p)])
	return ""


func test_dropped_glow_blinks_with_its_sprite() -> String:
	var p: Node2D = PICKUP.instantiate()
	_stage.add_child(p)
	p.set_process(false)
	var glow: Node2D = p.get_node("Glow")
	p._process(PowerupRules.PICKUP_LIFETIME - PowerupRules.PICKUP_BLINK_LEAD + 0.01)
	for i in 60:
		p._process(0.02)
		if glow.visible != p.sprite.visible:
			return _T.assert_true(false, "glow visible %s vs sprite %s" % [glow.visible, p.sprite.visible])
	return ""


func test_heart_collect_bursts_like_a_powerup() -> String:
	var heart: Node2D = (load(HEART) as PackedScene).instantiate()
	_stage.add_child(heart)
	var sprite: Sprite2D = heart.get_node("Sprite2D")
	var start := sprite.scale.x
	var player: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_stage.add_child(player)
	heart.collect_heart(player)
	for i in 6:
		await _tree().process_frame
	return _T.assert_gt(sprite.scale.x, start * 1.2, "heart sprite scales up as it is collected")
