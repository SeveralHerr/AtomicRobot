extends RefCounted

## A heart pickup draws BEHIND the trees it is placed beside, never under a crate.
##
## History: hearts first sat at z 0 under the tree's z 1, and one at a tree's foot
## (main.tscn, x~2944) read as a maid's speech bubble tangled in the canopy, so they
## were lifted to z 2. The player then asked for the opposite (2026-10-04): HP pickups
## belong behind the trees, the trunk passing in front of the atom. Every heart x every
## tree/crate pair is checked, in both scenes that hold hearts, plus the bare scene the
## door encounter and boss room drop at runtime.

var _T

const HEART := "res://scenes/atomic_heart_pickup.tscn"
const TREE := "res://scenes/tree.tscn"
const CRATE := "res://scenes/crate.tscn"
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


func test_heart_draws_under_every_tree_and_not_under_crates() -> String:
	var checked := 0
	for level_path in LEVELS:
		var level: Node = (load(level_path) as PackedScene).instantiate()
		var hearts: Array = []
		_collect(level, HEART, hearts)
		var trees: Array = []
		_collect(level, TREE, trees)
		var crates: Array = []
		_collect(level, CRATE, crates)
		for h in hearts:
			var hz := _effective_z(h)
			for t in trees:
				checked += 1
				if hz >= _effective_z(t):
					var msg := "%s: heart %s (z %d) is not under tree %s (z %d)" % [
						level_path, level.get_path_to(h), hz, level.get_path_to(t), _effective_z(t)]
					level.free()
					return _T.assert_true(false, msg)
			for c in crates:
				checked += 1
				if hz < _effective_z(c):
					var msg := "%s: heart %s (z %d) is under crate %s (z %d)" % [
						level_path, level.get_path_to(h), hz, level.get_path_to(c), _effective_z(c)]
					level.free()
					return _T.assert_true(false, msg)
		level.free()
	return _T.assert_gt(checked, 0, "found heart/scenery pairs to check")


## Door-encounter and boss-room hearts are instantiated bare under a z-0 parent.
func test_dropped_heart_draws_under_trees() -> String:
	var heart: Node = (load(HEART) as PackedScene).instantiate()
	var tree: Node = (load(TREE) as PackedScene).instantiate()
	var hz := _effective_z(heart)
	var tz := _effective_z(tree)
	heart.free()
	tree.free()
	return _T.assert_gt(tz, hz, "a tree's z vs a dropped heart's z")
