extends SceneTree
## Extracts a node subtree out of a scene into its own .tscn file, then
## replaces it in the original scene with an instance of that new file.
## Sibling order, transform, and script/property values are preserved
## exactly; unique_id scene-diff metadata is not (harmless, regenerated
## by the editor on next manual save).
##
## Usage:
##   godot --headless --path . --script res://tools/extract_subscene.gd -- \
##     --scene res://scenes/main.tscn --node_path Level/SceneItemsBackground/BuildingGroup1 \
##     --out res://scenes/building_group_1.tscn

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var opts := {}
	var i := 0
	while i < args.size():
		var key: String = args[i]
		if key.begins_with("--") and i + 1 < args.size():
			opts[key.substr(2)] = args[i + 1]
			i += 2
		else:
			i += 1

	if not (opts.has("scene") and opts.has("node_path") and opts.has("out")):
		push_error("Usage: -- --scene res://... --node_path A/B/C --out res://...")
		quit(1)
		return

	var scene_path: String = opts["scene"]
	var node_path: String = opts["node_path"]
	var out_path: String = opts["out"]

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("Failed to load scene: %s" % scene_path)
		quit(1)
		return

	var root: Node = packed.instantiate()
	var target: Node = root.get_node_or_null(NodePath(node_path))
	if target == null:
		push_error("Node not found: %s in %s" % [node_path, scene_path])
		quit(1)
		return

	var parent: Node = target.get_parent()
	var idx: int = target.get_index()
	var original_name: String = target.name

	var old_root: Node = root
	parent.remove_child(target)
	target.owner = null
	_reown(target, old_root, target)

	var extracted := PackedScene.new()
	var err := extracted.pack(target)
	if err != OK:
		push_error("pack() failed for %s: %d" % [node_path, err])
		quit(1)
		return
	err = ResourceSaver.save(extracted, out_path)
	if err != OK:
		push_error("save() failed for %s: %d" % [out_path, err])
		quit(1)
		return

	target.queue_free()

	var reloaded: PackedScene = load(out_path)
	var new_instance: Node = reloaded.instantiate()
	new_instance.name = original_name
	parent.add_child(new_instance)
	parent.move_child(new_instance, idx)
	new_instance.owner = root

	var main_packed := PackedScene.new()
	err = main_packed.pack(root)
	if err != OK:
		push_error("re-pack failed for %s: %d" % [scene_path, err])
		quit(1)
		return
	err = ResourceSaver.save(main_packed, scene_path)
	if err != OK:
		push_error("re-save failed for %s: %d" % [scene_path, err])
		quit(1)
		return

	print("Extracted %s -> %s (reinserted as instance at sibling index %d)" % [node_path, out_path, idx])
	quit(0)

## Only re-owns nodes that were actually owned by the scene root before
## extraction (i.e. genuinely "editable children" exposed in the source
## scene). Nodes with owner == null (opaque internals of an un-edited
## nested instance, e.g. AtomicBuildingGroup's own children) are left
## alone so they stay opaque instance internals in the new file instead
## of being flattened into loose override nodes.
func _reown(node: Node, old_owner: Node, new_owner: Node) -> void:
	for child in node.get_children():
		if child.owner == old_owner:
			child.owner = new_owner
		_reown(child, old_owner, new_owner)
