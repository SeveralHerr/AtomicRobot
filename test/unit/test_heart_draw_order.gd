extends RefCounted

## A heart pickup must draw over the street furniture it is placed beside.
##
## The bug: a level heart sat at a tree's foot (main.tscn, x~2944, beside the crates)
## at z 0 under the tree's z 1, so the trunk and leaves cut through the spinning atom.
## Its white sticker outline then read as a meter maid's speech bubble tangled in the
## tree. Every heart x every tree/crate pair is checked, in both scenes that hold
## hearts, plus the bare scene the door encounter and boss room drop at runtime.

var _T

const HEART := "res://scenes/atomic_heart_pickup.tscn"
const SCENERY := ["res://scenes/tree.tscn", "res://scenes/crate.tscn"]
const LEVELS := ["res://scenes/main.tscn", "res://scenes/boss_room.tscn"]


## Draw z after z_as_relative chains, the number Godot actually sorts on.
static func _effective_z(n: Node) -> int:
	var z := 0
	var cur: Node = n
	while cur is CanvasItem:
		z += (cur as CanvasItem).z_index
		if not (cur as CanvasItem).z_as_relative:
			break
		cur = cur.get_parent()
	return z


static func _collect(n: Node, path: String, out: Array) -> void:
	if n.scene_file_path == path:
		out.append(n)
	for c in n.get_children():
		_collect(c, path, out)


func test_heart_draws_over_every_tree_and_crate() -> String:
	var checked := 0
	for level_path in LEVELS:
		var level: Node = (load(level_path) as PackedScene).instantiate()
		var hearts: Array = []
		_collect(level, HEART, hearts)
		var props: Array = []
		for s in SCENERY:
			_collect(level, s, props)
		for h in hearts:
			for p in props:
				checked += 1
				if _effective_z(h) <= _effective_z(p):
					var msg := "%s: heart %s (z %d) is under %s (z %d)" % [
						level_path, level.get_path_to(h), _effective_z(h),
						level.get_path_to(p), _effective_z(p)]
					level.free()
					return _T.assert_true(false, msg)
		level.free()
	return _T.assert_gt(checked, 0, "found heart/scenery pairs to check")


## Door-encounter and boss-room hearts are instantiated bare under a z-0 parent.
func test_dropped_heart_draws_over_trees() -> String:
	var heart: Node = (load(HEART) as PackedScene).instantiate()
	var tree: Node = (load(SCENERY[0]) as PackedScene).instantiate()
	var hz := _effective_z(heart)
	var tz := _effective_z(tree)
	heart.free()
	tree.free()
	return _T.assert_gt(hz, tz, "a dropped heart's z vs a tree's z")
