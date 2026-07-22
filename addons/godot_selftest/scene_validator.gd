extends RefCounted
# NOTE: intentionally namespaced (not the bare `SceneValidator`) so this addon
# never collides with a project that already defines its own validator class.
# The DevTools core loads this by path, so the class_name is for convenience only.
class_name GodotSelftestSceneValidator


const SEVERITY_ERROR: String = "error"
const SEVERITY_WARNING: String = "warning"
const SEVERITY_INFO: String = "info"


static func validate_scene(scene_path: String) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []

	# Phase 1: File & Load checks
	if not FileAccess.file_exists(scene_path):
		issues.append(_issue(SEVERITY_ERROR, "file_not_found", "File not found: %s" % scene_path))
		return issues

	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		issues.append(_issue(SEVERITY_ERROR, "load_failed", "Failed to load scene: %s" % scene_path))
		return issues

	var state: SceneState = packed_scene.get_state()
	if state == null:
		issues.append(_issue(SEVERITY_ERROR, "invalid_state", "Scene state is null: %s" % scene_path))
		return issues

	# Phase 2: SceneState structure validation
	_validate_node_structure(state, issues)

	# Phase 3: Signal connection validation
	_validate_connections(state, issues)

	# Phase 4: Instantiation validation
	_validate_instantiated(packed_scene, issues)

	return issues


static func _validate_node_structure(state: SceneState, issues: Array[Dictionary]) -> void:
	var node_count: int = state.get_node_count()
	for i: int in range(node_count):
		var node_name: StringName = state.get_node_name(i)
		var prop_count: int = state.get_node_property_count(i)

		for pidx: int in range(prop_count):
			var prop_name: String = state.get_node_property_name(i, pidx)
			var value: Variant = state.get_node_property_value(i, pidx)

			if prop_name == "script" and typeof(value) == TYPE_OBJECT and value == null:
				issues.append(_issue(
					SEVERITY_ERROR,
					"missing_script",
					"Node '%s' has a null script resource" % node_name
				))
				continue

			if typeof(value) == TYPE_OBJECT and value == null:
				issues.append(_issue(
					SEVERITY_WARNING,
					"missing_resource",
					"Node '%s' property '%s' has a null resource" % [node_name, prop_name]
				))
				continue

			if typeof(value) == TYPE_NODE_PATH:
				var path_str: String = str(value)
				if path_str.contains(".."):
					issues.append(_issue(
						SEVERITY_INFO,
						"relative_nodepath",
						"Node '%s' property '%s' uses relative path: %s" % [node_name, prop_name, path_str]
					))


static func _validate_connections(state: SceneState, issues: Array[Dictionary]) -> void:
	var connection_count: int = state.get_connection_count()
	for i: int in range(connection_count):
		var signal_name: StringName = state.get_connection_signal(i)
		var source: NodePath = state.get_connection_source(i)
		var method: StringName = state.get_connection_method(i)

		if str(method).is_empty():
			issues.append(_issue(
				SEVERITY_ERROR,
				"invalid_connection",
				"Signal '%s' from '%s' has an empty method target" % [signal_name, source]
			))


static func _validate_instantiated(packed_scene: PackedScene, issues: Array[Dictionary]) -> void:
	var instance: Node = packed_scene.instantiate()
	if instance == null:
		issues.append(_issue(
			SEVERITY_ERROR,
			"instantiate_failed",
			"Failed to instantiate scene"
		))
		return

	_walk_node_tree(instance, issues)
	instance.free()


static func _walk_node_tree(node: Node, issues: Array[Dictionary]) -> void:
	if node is Sprite2D:
		var sprite: Sprite2D = node as Sprite2D
		if sprite.texture == null:
			issues.append(_issue(
				SEVERITY_WARNING,
				"missing_texture",
				"Sprite2D '%s' has no texture assigned" % node.name
			))

	if node is CollisionShape2D:
		var collision: CollisionShape2D = node as CollisionShape2D
		if collision.shape == null:
			issues.append(_issue(
				SEVERITY_WARNING,
				"missing_collision_shape",
				"CollisionShape2D '%s' has no shape assigned" % node.name
			))

	if node is AudioStreamPlayer:
		var audio: AudioStreamPlayer = node as AudioStreamPlayer
		if audio.stream == null:
			issues.append(_issue(
				SEVERITY_INFO,
				"missing_audio",
				"AudioStreamPlayer '%s' has no stream assigned" % node.name
			))

	if node is AnimationPlayer:
		var anim_player: AnimationPlayer = node as AnimationPlayer
		_validate_animation_player(anim_player, issues)

	for child: Node in node.get_children():
		_walk_node_tree(child, issues)


static func _validate_animation_player(anim_player: AnimationPlayer, issues: Array[Dictionary]) -> void:
	# Skip animation path validation when the node is not in a scene tree,
	# as get_node_or_null() cannot resolve paths without a tree context.
	if not anim_player.is_inside_tree():
		return

	var anim_names: PackedStringArray = anim_player.get_animation_list()
	for anim_name: String in anim_names:
		var animation: Animation = anim_player.get_animation(anim_name)
		if animation == null:
			continue
		var track_count: int = animation.get_track_count()
		for t: int in range(track_count):
			var track_path: NodePath = animation.track_get_path(t)
			var root_node: Node = anim_player.get_node_or_null(anim_player.root_node)
			if root_node == null:
				continue
			var target_node: Node = root_node.get_node_or_null(str(track_path).split(":")[0])
			if target_node == null:
				issues.append(_issue(
					SEVERITY_WARNING,
					"invalid_animation_path",
					"AnimationPlayer '%s' animation '%s' track %d targets missing node: %s" % [
						anim_player.name, anim_name, t, track_path
					]
				))


static func _issue(severity: String, code: String, message: String) -> Dictionary:
	return {
		"severity": severity,
		"code": code,
		"message": message,
	}
