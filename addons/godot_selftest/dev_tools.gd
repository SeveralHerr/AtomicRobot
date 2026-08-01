extends Node

## Generic DevTools autoload providing a file-based command interface for
## automation, testing, and CI. Commands are read from a JSON file on disk,
## dispatched to registered handlers, and results written back.
##
## This is the game-agnostic core of the godot_selftest harness. It ships only
## engine-generic verbs (ping, screenshot, scene tree, state/method access,
## action + touch input simulation, time stepping, engine feature flags,
## scene/UI validation, ...). Project-specific verbs live in a
## registry extension script (see devtools_config.json -> "extension_script")
## that implements `register_commands(dev: Node) -> void` and calls
## `dev.register_command(action, handler)` for each verb it adds. Because the
## extension loads AFTER the generic handlers, a project may override a generic
## verb by registering the same action string (last-writer-wins).

# --- Constants ---

const COMMANDS_PATH: String = "user://devtools_commands.json"
const RESULTS_PATH: String = "user://devtools_results.json"
const LOG_PATH: String = "user://devtools_log.jsonl"
const CONFIG_PATH: String = "res://addons/godot_selftest/devtools_config.json"

## Frames to let elapse after _ready() before sampling the orphan-node baseline, so
## the main scene has finished coming up. ~0.5s at the default 60 FPS.
const ORPHAN_BASELINE_FRAMES: int = 30

## Hard ceiling on a single step_time request. The bridge serves one command at a
## time, so a typo'd "seconds" would otherwise wedge it for as long as the typo says.
const STEP_TIME_MAX_SECONDS: float = 60.0

## Default configuration, used verbatim when CONFIG_PATH is missing. Keys read by
## this core: validator_script, extension_script, hud_layer_name, scan_root,
## safe_area_inset. Remaining keys are consumed by sibling tools (lint_project.gd,
## run_tests.gd, the Python client, and the /verify command) and are carried here so
## the whole harness shares one schema.
##
## Every key MUST have a default here: a project whose devtools_config.json predates
## a new key still has to work, and _load_config() only overlays the keys it finds.
const DEFAULT_CONFIG: Dictionary = {
	"validator_script": "res://addons/godot_selftest/scene_validator.gd",
	"extension_script": "res://devtools_ext/commands.gd",
	"hud_layer_name": "HUD",
	"test_dir": "res://test/unit",
	"scan_root": "res://",
	"fps_min": 30,
	# Absolute orphan ceiling. Kept for compatibility; note that 0 is unreachable in
	# a real project (a fresh launch routinely reports dozens before any test action),
	# so prefer gating on orphan_growth_max. See _capture_orphan_baseline().
	"orphan_max": 0,
	# Tolerated growth in orphan nodes between the startup baseline and now. This is
	# the number a run can actually be held to.
	"orphan_growth_max": 20,
	# Pixels trimmed off each viewport edge before validate_ui judges whether a
	# control is on screen. Use it for a decorative overlay -- a CRT bezel, a notch,
	# a rounded corner -- that eats screen edges the viewport rect knows nothing
	# about. All-zero (the default) disables the check entirely.
	"safe_area_inset": {"left": 0, "top": 0, "right": 0, "bottom": 0},
	"main_scene": "",
	"entry_hook": {"node_path": "", "method": ""},
	"mute": true,
}

# --- Variables ---

var _commands_abs_path: String
var _results_abs_path: String
var _log_abs_path: String
var _last_command_check_msec: int = 0
var _config: Dictionary = {}
var _handlers: Dictionary = {}
## Optional project-supplied callable whose Dictionary is merged into every response
## as "status". See register_status_provider().
var _status_provider: Callable = Callable()
var _active_simulated_inputs: Array[String] = []
## Simulated touches currently held down: { index: int -> position: Vector2 }.
## Kept so a release can default to the last known position, and so a run cannot
## end leaving phantom fingers down. See _clear_all_simulated_touches().
var _active_touches: Dictionary = {}
## Orphan-node count sampled shortly after startup, or -1 before it is captured.
## See _capture_orphan_baseline() for why an absolute orphan ceiling is useless.
var _orphan_baseline: int = -1
## The "id" of the command currently being served, echoed verbatim onto its reply
## ("" when the request carried none).
##
## THIS IS A PURE ECHO AND NOT CONCURRENCY SUPPORT. The bridge is still strictly
## single-in-flight: one command file, one result file, no locking, no queue. The id
## exists only so that a crossed reply is DETECTABLE -- the client compares the
## echoed id against the one it sent and can tell "this is not my answer" instead of
## silently parsing another request's payload and reporting a missing key. Driving
## the bridge from two threads is still wrong; it is now merely loud about it.
var _current_request_id: String = ""
# Live reference to the instantiated registry extension. MUST be held so the
# Callables it bound (via register_command) are not freed out from under us.
var _extension: RefCounted = null


# --- Lifecycle ---

func _ready() -> void:
	_commands_abs_path = ProjectSettings.globalize_path(COMMANDS_PATH)
	_results_abs_path = ProjectSettings.globalize_path(RESULTS_PATH)
	_log_abs_path = ProjectSettings.globalize_path(LOG_PATH)

	_load_config()
	_register_generic_handlers()
	_load_extension()

	_clear_stale_files()
	_write_log("system", "DevTools initialized", {
		"commands_path": _commands_abs_path,
		"results_path": _results_abs_path,
		"handlers": _handlers.size(),
	})

	_process_command_line_args()
	_capture_orphan_baseline()


func _process(_delta: float) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_command_check_msec >= 100:
		_last_command_check_msec = now_msec
		_check_for_commands()


func _exit_tree() -> void:
	_clear_all_simulated_inputs()
	_clear_all_simulated_touches()


# --- Public API ---

## Registers a handler for a bus action. Last writer wins, so a project's
## extension may override a generic verb by re-registering its action string.
## Handler signature: func(args: Dictionary) -> Dictionary returning exactly
## { "success": bool, "message": String, "data": Dictionary }.
##
## Guidance for SETTER verbs: leave the system in a state the game itself can reach.
## A debug verb that writes one half of an invariant pair is a latent trap. It
## manufactures a state no real play session can produce, so whatever you observe
## afterwards is the behavior of an impossible state -- and the verb rots silently
## the moment anything starts reading the other half. (Real case: a set_combo that
## wrote the combo count but not the combo window. It looked fine while the HUD drew
## the count unconditionally, and became useless the day the readout began fading on
## the window timer. Nothing announced the change.) If the value you are writing has
## a partner -- a timer, a window, a flag, a matching entry in some registry -- write
## the partner too, or better, route the write through the same method the game
## itself calls.
func register_command(action: String, handler: Callable) -> void:
	_handlers[action] = handler


## Registers a callable whose return Dictionary is merged into EVERY response under
## "status". Signature: func(args: Dictionary) -> Dictionary. Pass an empty Callable
## to clear it. At most one provider is active; last writer wins.
##
## Use it for the handful of facts that decide whether a reading means anything at all
## — typically "is the thing under test still alive/running". Without it, a session
## that has silently entered a dead or frozen state keeps answering every query with
## well-formed zeros, which reads identically to a genuine all-clear result. Keep the
## payload tiny: it rides on every single reply.
func register_status_provider(provider: Callable) -> void:
	_status_provider = provider


# --- Setup ---

func _load_config() -> void:
	_config = DEFAULT_CONFIG.duplicate(true)
	if not FileAccess.file_exists(CONFIG_PATH):
		return

	var json_text: String = FileAccess.get_file_as_string(CONFIG_PATH)
	if json_text.is_empty():
		return

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		_write_log("error", "Failed to parse config JSON; using defaults", {"path": CONFIG_PATH})
		return

	for key: String in (parsed as Dictionary):
		_config[key] = (parsed as Dictionary)[key]


func _register_generic_handlers() -> void:
	register_command("ping", _cmd_ping)
	register_command("screenshot", _cmd_screenshot)
	register_command("scene_tree", _cmd_scene_tree)
	register_command("validate_scene", _cmd_validate_scene)
	register_command("validate_all", _cmd_validate_all)
	register_command("get_state", _cmd_get_state)
	register_command("set_state", _cmd_set_state)
	register_command("run_method", _cmd_run_method)
	register_command("performance", _cmd_performance)
	register_command("quit", _cmd_quit)
	register_command("input_press", _cmd_input_press)
	register_command("input_release", _cmd_input_release)
	register_command("input_tap", _cmd_input_tap)
	register_command("input_clear", _cmd_input_clear)
	register_command("input_actions", _cmd_input_actions)
	register_command("input_sequence", _cmd_input_sequence)
	register_command("touch_press", _cmd_touch_press)
	register_command("touch_release", _cmd_touch_release)
	register_command("touch_drag", _cmd_touch_drag)
	register_command("touch_clear", _cmd_touch_clear)
	register_command("touch_list", _cmd_touch_list)
	register_command("set_feature", _cmd_set_feature)
	register_command("set_game_speed", _cmd_set_game_speed)
	register_command("step_time", _cmd_step_time)
	register_command("wait_frames", _cmd_wait_frames)
	register_command("clear_nodes", _cmd_clear_nodes)
	register_command("validate_ui", _cmd_validate_ui)
	register_command("get_ui_snapshot", _cmd_get_ui_snapshot)
	register_command("get_node_bounds", _cmd_get_node_bounds)
	register_command("save_ui_baseline", _cmd_save_ui_baseline)
	register_command("ui_snapshot_diff", _cmd_ui_snapshot_diff)
	register_command("list_commands", _cmd_list_commands)


func _load_extension() -> void:
	var ext_path: String = _config.get("extension_script", "")
	if ext_path.is_empty():
		return
	if not ResourceLoader.exists(ext_path):
		_write_log("system", "No registry extension found", {"path": ext_path})
		return

	var script: GDScript = load(ext_path) as GDScript
	if script == null:
		_write_log("error", "Failed to load registry extension", {"path": ext_path})
		return

	var instance: Variant = script.new()
	if instance == null or not instance is RefCounted:
		_write_log("error", "Registry extension did not produce a RefCounted instance", {"path": ext_path})
		return
	if not (instance as Object).has_method("register_commands"):
		_write_log("error", "Registry extension has no register_commands(dev) method", {"path": ext_path})
		return

	# Hold the instance so its bound Callables stay alive.
	_extension = instance
	_extension.register_commands(self)
	_write_log("system", "Registry extension loaded", {"path": ext_path, "handlers": _handlers.size()})


# --- Command Processing ---

func _check_for_commands() -> void:
	if not FileAccess.file_exists(COMMANDS_PATH):
		return

	var json_text: String = FileAccess.get_file_as_string(COMMANDS_PATH)
	DirAccess.remove_absolute(_commands_abs_path)

	if json_text.is_empty():
		_write_log("error", "Empty command file")
		return

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		_write_log("error", "Failed to parse command JSON", {"raw": json_text.substr(0, 200)})
		return

	var command: Dictionary = parsed
	var action: String = command.get("action", "")
	var args: Dictionary = command.get("args", {})

	# Echo the caller's opaque request id back on the reply. Absent -> "". See the
	# _current_request_id declaration: this makes a crossed reply detectable, it does
	# NOT make the bridge concurrency-safe.
	var raw_id: Variant = command.get("id", "")
	var request_id: String = str(raw_id) if raw_id != null else ""
	_current_request_id = request_id

	if action.is_empty():
		_write_result("unknown", {"success": false, "message": "No action specified"})
		return

	if not _handlers.has(action):
		_write_result(action, {"success": false, "message": "Unknown action: %s" % action})
		_write_log("error", "Unknown action: %s" % action)
		return

	_write_log("command", "Executing: %s" % action, args)

	var handler: Callable = _handlers[action]
	var result: Dictionary = await handler.call(args)
	# A command that arrived while this one was awaiting (step_time, input_tap, a
	# long project verb) would have moved _current_request_id. Restore ours so this
	# reply carries the id of the request it actually answers.
	_current_request_id = request_id
	_write_result(action, result)


## Writes the single result file. `id` is always present -- the request's id verbatim,
## or "" when the request carried none -- so a client can reject a reply that is not
## its own instead of parsing it as an answer.
func _write_result(action: String, result: Dictionary) -> void:
	var response: Dictionary = {
		"id": _current_request_id,
		"action": action,
		"success": result.get("success", false),
		"message": result.get("message", ""),
		"data": result.get("data"),
		"timestamp": Time.get_unix_time_from_system(),
	}
	var status: Dictionary = _collect_status()
	if not status.is_empty():
		response["status"] = status
	var file: FileAccess = FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
	if file == null:
		_write_log("error", "Failed to write result file", {"error": FileAccess.get_open_error()})
		return
	file.store_string(JSON.stringify(response, "  "))
	file.close()


## Never let a broken provider take the bridge down: a status hook that errors would
## otherwise poison every reply, including the ones you would use to diagnose it.
func _collect_status() -> Dictionary:
	if not _status_provider.is_valid():
		return {}
	var out: Variant = _status_provider.call({})
	return out if out is Dictionary else {}


func _process_command_line_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	for arg in args:
		match arg:
			"--devtools-screenshot":
				# Take a screenshot on the next frame so the scene is rendered.
				await get_tree().process_frame
				var result: Dictionary = _cmd_screenshot({})
				_write_log("cli", "CLI screenshot", result)
			"--devtools-validate":
				# Validate after the scene tree is ready.
				await get_tree().process_frame
				var result: Dictionary = _cmd_validate_all({})
				_write_result("validate_all", result)
				_write_log("cli", "CLI validate_all", {"success": result.get("success", false)})


# --- Command Handlers ---

func _cmd_ping(_args: Dictionary) -> Dictionary:
	return {
		"success": true,
		"message": "pong",
		"data": {"timestamp": Time.get_unix_time_from_system()},
	}


func _cmd_screenshot(args: Dictionary) -> Dictionary:
	var default_name: String = "screenshot_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	var filename: String = args.get("filename", default_name)
	var screenshots_dir: String = ProjectSettings.globalize_path("user://screenshots")
	DirAccess.make_dir_recursive_absolute(screenshots_dir)

	var abs_path: String = screenshots_dir.path_join(filename)
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		return {"success": false, "message": "Failed to capture viewport image"}

	var err: Error = image.save_png(abs_path)
	if err != OK:
		return {"success": false, "message": "Failed to save PNG: error %d" % err}

	return {
		"success": true,
		"message": "Screenshot saved",
		"data": {
			"path": abs_path,
			"width": image.get_width(),
			"height": image.get_height(),
			"size_bytes": FileAccess.get_file_as_bytes(abs_path).size() if FileAccess.file_exists(abs_path) else -1,
		},
	}


func _cmd_scene_tree(args: Dictionary) -> Dictionary:
	var depth: int = args.get("depth", 10)
	var root: Node = get_tree().current_scene
	if root == null:
		return {"success": false, "message": "No current scene"}

	var tree_data: Dictionary = _serialize_node(root, depth)
	return {
		"success": true,
		"message": "Scene tree captured",
		"data": tree_data,
	}


func _serialize_node(node: Node, depth: int) -> Dictionary:
	var data: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}

	if node is Node2D:
		var n2d: Node2D = node as Node2D
		data["position"] = {"x": n2d.position.x, "y": n2d.position.y}
		data["rotation"] = n2d.rotation
		data["visible"] = n2d.visible

	if node is Control:
		var ctrl: Control = node as Control
		data["position"] = {"x": ctrl.position.x, "y": ctrl.position.y}
		data["size"] = {"x": ctrl.size.x, "y": ctrl.size.y}
		data["visible"] = ctrl.visible

	if depth > 0 and node.get_child_count() > 0:
		var children: Array = []
		for child in node.get_children():
			children.append(_serialize_node(child, depth - 1))
		data["children"] = children

	return data


func _cmd_validate_scene(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty():
		return {"success": false, "message": "No scene path provided"}

	var validator_script: GDScript = _load_validator()
	if validator_script == null:
		return {"success": false, "message": "Validator script not found: %s" % _config.get("validator_script", "")}

	var issues: Array = validator_script.validate_scene(path)
	return {
		"success": issues.is_empty(),
		"message": "%d issues found" % issues.size() if not issues.is_empty() else "No issues found",
		"data": {"path": path, "issues": issues},
	}


func _cmd_validate_all(_args: Dictionary) -> Dictionary:
	var validator_script: GDScript = _load_validator()
	if validator_script == null:
		return {"success": false, "message": "Validator script not found: %s" % _config.get("validator_script", "")}

	var scan_root: String = _config.get("scan_root", "res://")
	var scenes: Array[String] = _find_all_scenes(scan_root)
	var all_issues: Array = []
	var scene_results: Array = []

	for scene_path in scenes:
		var issues: Array = validator_script.validate_scene(scene_path)
		scene_results.append({
			"path": scene_path,
			"issues": issues,
			"valid": issues.is_empty(),
		})
		all_issues.append_array(issues)

	return {
		"success": all_issues.is_empty(),
		"message": "%d scenes validated, %d total issues" % [scenes.size(), all_issues.size()],
		"data": {
			"total_scenes": scenes.size(),
			"total_issues": all_issues.size(),
			"scenes": scene_results,
		},
	}


## Reads a node's state. Two deliberate departures from a plain property dump:
##
## 1. args["properties"] -- an Array of property-name Strings (a bare String is also
##    accepted) -- narrows the response to just those properties. An unfiltered read
##    of a Label is ~120 keys and of a typical game node ~200, which is a lot of
##    tokens to grep for one number. A requested name the node does NOT have is
##    listed in data["missing"] rather than silently dropped: a silent omission is
##    indistinguishable from "the value happens to be absent", which is exactly how
##    the transform bug below stayed invisible for weeks. The read itself still
##    reports success -- probing for an optional property is a legitimate use -- so
##    check data["missing"], which is always present when a filter was supplied.
##
## 2. data["transform"] is ALWAYS present, filter or no filter, and is read straight
##    off the node instead of through get_property_list(). This is not redundancy.
##    Godot clears PROPERTY_USAGE_STORAGE on position/rotation/scale/pivot_offset for
##    the children of a Container, so the enumeration above cannot see them at all --
##    a scale animation on a VBoxContainer child is completely absent from the dump
##    while working perfectly on screen. (Verified on 4.7.1: a Label under a plain
##    Control reports scale with usage 6; the same Label under a VBoxContainer
##    reports it with usage 0x10000004, which fails the filter.) Controls also expose
##    offset_transform_scale, which stays 1.0 while the node visibly scales, so the
##    enumerated dump can be actively misleading. data["transform"] is the value to
##    assert on. Requesting "transform" in args["properties"] is accepted and never
##    counts as missing.
##
##    Note: data["transform"] shadows the engine's own raw `transform` property (a
##    Transform2D / Transform3D) on nodes that have one. Nothing readable was lost --
##    that property carries usage 0 and so never passed the filter anyway.
func _cmd_get_state(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	if node_path.is_empty():
		return {"success": false, "message": "No node_path provided"}

	var node: Node = get_node_or_null(node_path)
	if node == null:
		return {"success": false, "message": "Node not found: %s" % node_path}

	var wanted: Array = []
	var raw_wanted: Variant = args.get("properties", [])
	if raw_wanted is String:
		wanted = [raw_wanted]
	elif raw_wanted is Array:
		wanted = raw_wanted
	elif raw_wanted != null:
		return {"success": false, "message": "args.properties must be an array of property names"}

	var state: Dictionary = {}
	for prop in node.get_property_list():
		var usage: int = prop.get("usage", 0)
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE or usage & PROPERTY_USAGE_STORAGE:
			var prop_name: String = prop["name"]
			state[prop_name] = _serialize_variant(node.get(prop_name))

	var data: Dictionary = state
	var missing: Array = []

	if not wanted.is_empty():
		var filtered: Dictionary = {}
		for entry: Variant in wanted:
			var prop_name: String = str(entry)
			if prop_name == "transform":
				# Always served below, from the node itself.
				continue
			if state.has(prop_name):
				filtered[prop_name] = state[prop_name]
			elif prop_name in node:
				# Present on the node but hidden from the enumeration above (container
				# child, editor-only usage flags, ...). Read it directly.
				filtered[prop_name] = _serialize_variant(node.get(prop_name))
			else:
				missing.append(prop_name)
		filtered["missing"] = missing
		data = filtered

	data["transform"] = _read_transform(node)

	var message: String = "State retrieved for %s" % node_path
	if not missing.is_empty():
		message += " -- %d requested propert%s not found on this node: %s" % [
			missing.size(),
			"y" if missing.size() == 1 else "ies",
			", ".join(PackedStringArray(missing)),
		]

	return {
		"success": true,
		"message": message,
		"data": data,
	}


## Reads a node's live transform directly off the object, bypassing
## get_property_list() entirely -- see _cmd_get_state for why that indirection is
## unreliable. Returns an empty Dictionary for a node with no spatial transform.
func _read_transform(node: Node) -> Dictionary:
	var out: Dictionary = {}

	if node is Node2D:
		var n2d: Node2D = node as Node2D
		out["space"] = "2d"
		out["position"] = _serialize_variant(n2d.position)
		out["global_position"] = _serialize_variant(n2d.global_position)
		out["rotation"] = n2d.rotation
		out["rotation_degrees"] = rad_to_deg(n2d.rotation)
		out["scale"] = _serialize_variant(n2d.scale)
		out["global_scale"] = _serialize_variant(n2d.global_scale)
		out["skew"] = n2d.skew
	elif node is Control:
		var ctrl: Control = node as Control
		out["space"] = "control"
		out["position"] = _serialize_variant(ctrl.position)
		out["global_position"] = _serialize_variant(ctrl.global_position)
		out["size"] = _serialize_variant(ctrl.size)
		out["global_rect"] = _serialize_variant(ctrl.get_global_rect())
		out["rotation"] = ctrl.rotation
		out["rotation_degrees"] = rad_to_deg(ctrl.rotation)
		out["scale"] = _serialize_variant(ctrl.scale)
		out["pivot_offset"] = _serialize_variant(ctrl.pivot_offset)
	elif node is Node3D:
		var n3d: Node3D = node as Node3D
		out["space"] = "3d"
		out["position"] = _serialize_variant(n3d.position)
		out["global_position"] = _serialize_variant(n3d.global_position)
		out["rotation"] = _serialize_variant(n3d.rotation)
		out["rotation_degrees"] = _serialize_variant(n3d.rotation_degrees)
		out["scale"] = _serialize_variant(n3d.scale)

	if node is CanvasItem:
		var item: CanvasItem = node as CanvasItem
		out["visible"] = item.visible
		out["effective_visible"] = _is_effectively_visible(item)
		out["modulate_a"] = item.modulate.a
		out["effective_modulate_a"] = _get_effective_alpha(item)
	elif node is Node3D:
		out["visible"] = (node as Node3D).visible

	return out


func _cmd_set_state(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	if node_path.is_empty():
		return {"success": false, "message": "No node_path provided"}

	var node: Node = get_node_or_null(node_path)
	if node == null:
		return {"success": false, "message": "Node not found: %s" % node_path}

	var property: String = args.get("property", "")
	if property.is_empty():
		return {"success": false, "message": "No property specified"}

	var value: Variant = args.get("value")
	node.set(property, value)

	return {
		"success": true,
		"message": "Set %s.%s" % [node_path, property],
		"data": {"property": property, "value": _serialize_variant(node.get(property))},
	}


func _cmd_run_method(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	if node_path.is_empty():
		return {"success": false, "message": "No node_path provided"}

	var node: Node = get_node_or_null(node_path)
	if node == null:
		return {"success": false, "message": "Node not found: %s" % node_path}

	var method: String = args.get("method", "")
	if method.is_empty():
		return {"success": false, "message": "No method specified"}

	if not node.has_method(method):
		return {"success": false, "message": "Node %s has no method: %s" % [node_path, method]}

	var method_args: Array = args.get("args", [])
	var result: Variant = node.callv(method, method_args)

	return {
		"success": true,
		"message": "Called %s.%s()" % [node_path, method],
		"data": {"result": _serialize_variant(result)},
	}


## Collects engine metrics. Beyond the absolute counters it reports orphan GROWTH
## against a baseline sampled at startup (see _capture_orphan_baseline), because the
## absolute orphan count is not a number a project can be held to.
##
## args["reset_baseline"] = true re-samples the baseline from the current count
## before reporting, so growth is measured from here on. Call it once the game has
## reached the state a run actually starts from -- typically right after /verify's
## entry hook -- otherwise the scene load itself dominates the delta.
func _cmd_performance(args: Dictionary) -> Dictionary:
	var orphan_nodes: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	if bool(args.get("reset_baseline", false)):
		_orphan_baseline = orphan_nodes
		_write_log("system", "Orphan baseline reset", {"orphan_baseline": _orphan_baseline})

	var baseline_captured: bool = _orphan_baseline >= 0
	var orphan_growth: int = (orphan_nodes - _orphan_baseline) if baseline_captured else 0

	var fps: float = Engine.get_frames_per_second()
	var data: Dictionary = {
		"fps": fps,
		"frame_time_ms": 1000.0 / maxf(1.0, fps),
		"physics_fps": Engine.physics_ticks_per_second,
		"static_memory_mb": OS.get_static_memory_usage() / (1024.0 * 1024.0),
		"video_memory_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		# Absolute count, unchanged and still reported.
		"orphan_nodes": orphan_nodes,
		# Growth against the startup baseline. -1 baseline means "not sampled yet".
		"orphan_baseline": _orphan_baseline,
		"orphan_baseline_captured": baseline_captured,
		"orphan_growth": orphan_growth,
		# Both thresholds are echoed so a gate does not have to re-read the config.
		"orphan_max": int(_config.get("orphan_max", 0)),
		"orphan_growth_max": int(_config.get("orphan_growth_max", 20)),
		"physics_2d_active_objects": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"physics_3d_active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
	}

	var message: String = "Performance metrics collected"
	if baseline_captured:
		message += " (orphans %d, baseline %d, growth %d)" % [orphan_nodes, _orphan_baseline, orphan_growth]
	else:
		message += " (orphan baseline not sampled yet; growth is not meaningful)"

	return {
		"success": true,
		"message": message,
		"data": data,
	}


## Samples the orphan-node count once the main scene has settled, so `performance`
## can report orphan growth rather than only an absolute count.
##
## Why: an absolute ceiling of 0 is unreachable in a real project. A fresh launch
## into a main scene routinely reports dozens of orphans before any test action, and
## scene swaps push it into the hundreds; measured deltas of a few are noise. A
## threshold nothing can ever satisfy trains you to skip the check, which is worse
## than having no check. Growth against a launch baseline is a number a run can be
## held to -- see `orphan_growth_max` in devtools_config.json.
##
## Deliberately fire-and-forget: _ready() does not await it, so a slow first scene
## cannot delay the bridge coming up. Until it lands, _orphan_baseline stays -1 and
## `performance` says so rather than reporting a fictitious growth of 0.
func _capture_orphan_baseline() -> void:
	for _i: int in range(ORPHAN_BASELINE_FRAMES):
		await get_tree().process_frame
	_orphan_baseline = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_write_log("system", "Orphan baseline captured", {
		"orphan_baseline": _orphan_baseline,
		"frames_waited": ORPHAN_BASELINE_FRAMES,
	})


func _cmd_quit(args: Dictionary) -> Dictionary:
	var exit_code: int = args.get("exit_code", 0)
	_write_log("system", "Quit requested", {"exit_code": exit_code})
	# Write result before quitting so the caller can read it.
	_write_result("quit", {"success": true, "message": "Quitting with code %d" % exit_code})
	get_tree().quit(exit_code)
	# Return value won't be used since we quit, but needed for type safety.
	return {"success": true, "message": "Quitting"}


func _cmd_list_commands(_args: Dictionary) -> Dictionary:
	var actions: Array = _handlers.keys()
	actions.sort()
	return {
		"success": true,
		"message": "%d commands registered" % actions.size(),
		"data": {"actions": actions},
	}


# --- Node Lifecycle Handlers ---

func _cmd_clear_nodes(args: Dictionary) -> Dictionary:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return {"success": false, "message": "No current scene"}

	var group: String = args.get("group", "")
	var method: String = args.get("method", "")
	var cls: String = args.get("class", "")

	if group.is_empty() and method.is_empty() and cls.is_empty():
		return {
			"success": false,
			"message": "No selector provided. Supply exactly one of: group, method, or class (refusing to free the whole tree).",
		}

	var matches: Array[Node] = []
	_collect_matching_nodes(scene, group, method, cls, matches)

	var cleared: int = 0
	for node: Node in matches:
		node.queue_free()
		cleared += 1

	return {
		"success": true,
		"message": "Cleared %d nodes (group='%s', method='%s', class='%s')" % [cleared, group, method, cls],
		"data": {"count": cleared},
	}


func _collect_matching_nodes(node: Node, group: String, method: String, cls: String, matches: Array[Node]) -> void:
	for child: Node in node.get_children():
		if _node_matches(child, group, method, cls):
			matches.append(child)
		_collect_matching_nodes(child, group, method, cls, matches)


func _node_matches(node: Node, group: String, method: String, cls: String) -> bool:
	if not group.is_empty() and node.is_in_group(group):
		return true
	if not method.is_empty() and node.has_method(method):
		return true
	if not cls.is_empty() and (node.is_class(cls) or node.get_class() == cls):
		return true
	return false


# --- Input Simulation Handlers ---

## Input.action_press/action_release only update the polled action state; they never
## dispatch an InputEvent, so game code driven by _input/_unhandled_input (event-based
## handlers) would not see simulated input. Dispatch a matching InputEventAction too.
func _dispatch_action_event(action: String, pressed: bool, strength: float = 1.0) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = strength
	Input.parse_input_event(ev)


func _cmd_input_press(args: Dictionary) -> Dictionary:
	var action: String = args.get("action", "")
	if action.is_empty():
		return {"success": false, "message": "No action specified"}

	if not InputMap.has_action(action):
		return {"success": false, "message": "Unknown input action: %s" % action}

	var strength: float = args.get("strength", 1.0)
	Input.action_press(action, strength)
	_dispatch_action_event(action, true, strength)
	if action not in _active_simulated_inputs:
		_active_simulated_inputs.append(action)

	return {
		"success": true,
		"message": "Pressed: %s" % action,
		"data": {"action": action, "strength": strength, "active_inputs": _active_simulated_inputs.duplicate()},
	}


func _cmd_input_release(args: Dictionary) -> Dictionary:
	var action: String = args.get("action", "")
	if action.is_empty():
		return {"success": false, "message": "No action specified"}

	if not InputMap.has_action(action):
		return {"success": false, "message": "Unknown input action: %s" % action}

	Input.action_release(action)
	_dispatch_action_event(action, false)
	_active_simulated_inputs.erase(action)

	return {
		"success": true,
		"message": "Released: %s" % action,
		"data": {"action": action, "active_inputs": _active_simulated_inputs.duplicate()},
	}


func _cmd_input_tap(args: Dictionary) -> Dictionary:
	var action: String = args.get("action", "")
	if action.is_empty():
		return {"success": false, "message": "No action specified"}

	if not InputMap.has_action(action):
		return {"success": false, "message": "Unknown input action: %s" % action}

	var hold: float = args.get("seconds", args.get("hold", 0.0))
	var strength: float = args.get("strength", 1.0)

	Input.action_press(action, strength)
	_dispatch_action_event(action, true, strength)
	_active_simulated_inputs.append(action)

	get_tree().create_timer(maxf(hold, 0.0)).timeout.connect(func() -> void:
		Input.action_release(action)
		_dispatch_action_event(action, false)
		_active_simulated_inputs.erase(action)
	)

	return {
		"success": true,
		"message": "Tapped: %s (hold %.2fs)" % [action, hold],
		"data": {"action": action, "hold": hold, "strength": strength},
	}


func _cmd_input_clear(_args: Dictionary) -> Dictionary:
	var cleared: Array[String] = _clear_all_simulated_inputs()
	var released: Array = _clear_all_simulated_touches()
	return {
		"success": true,
		"message": "Cleared %d simulated inputs and released %d touches" % [cleared.size(), released.size()],
		"data": {"cleared": cleared, "touches_released": released},
	}


# --- Touch Simulation Handlers ---

## Touch has no polled equivalent of Input.action_press() -- InputEventScreenTouch /
## InputEventScreenDrag are event-only -- so a simulated touch must be injected with
## Input.parse_input_event(). Two consequences worth knowing before trusting a result:
##
##  * The game only sees these if it handles InputEventScreenTouch/Drag itself, or if
##    Input.set_emulate_mouse_from_touch() is on (it is, by default) and the game
##    handles the resulting mouse events.
##  * A game that hides its touch UI behind DisplayServer.is_touchscreen_available()
##    will not be showing that UI on a desktop run. Call `set_feature` with
##    {"touchscreen": true} first -- that is what it is for.
func _dispatch_touch(index: int, position: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = position
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _dispatch_drag(index: int, position: Vector2, relative: Vector2, delta: float) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = position
	ev.relative = relative
	# Velocity is what gesture code reads to decide flick vs. drag, so it has to be
	# derived from a real interval rather than left at zero.
	ev.velocity = relative / maxf(delta, 0.0001)
	Input.parse_input_event(ev)


## Presses a finger down. args: { "index": int = 0, "position": [x, y] }.
## `position` is required for an index that is not already held; for one that is, it
## defaults to that finger's last known position.
func _cmd_touch_press(args: Dictionary) -> Dictionary:
	var index: int = int(args.get("index", 0))
	var position: Vector2 = Vector2.ZERO

	if args.has("position"):
		var parsed: Variant = _parse_vector2_or_null(args["position"])
		if parsed == null:
			return {"success": false, "message": "'position' must be [x, y] or {\"x\": x, \"y\": y}"}
		position = parsed
	elif _active_touches.has(index):
		position = _active_touches[index]
	else:
		return {"success": false, "message": "touch_press on a new index requires 'position' as [x, y]"}

	_dispatch_touch(index, position, true)
	_active_touches[index] = position

	return {
		"success": true,
		"message": "Touch %d pressed at (%.1f, %.1f)" % [index, position.x, position.y],
		"data": {
			"index": index,
			"position": {"x": position.x, "y": position.y},
			"active_touches": _serialize_touches(),
		},
	}


## Lifts a finger. args: { "index": int = 0, "position": [x, y] optional }.
## `position` defaults to the last known position for that index. Releasing an index
## that is not held is allowed (it is the safe direction) and reported via
## data["was_held"].
func _cmd_touch_release(args: Dictionary) -> Dictionary:
	var index: int = int(args.get("index", 0))
	var was_held: bool = _active_touches.has(index)
	var position: Vector2 = _active_touches.get(index, Vector2.ZERO)

	if args.has("position"):
		var parsed: Variant = _parse_vector2_or_null(args["position"])
		if parsed == null:
			return {"success": false, "message": "'position' must be [x, y] or {\"x\": x, \"y\": y}"}
		position = parsed

	_dispatch_touch(index, position, false)
	_active_touches.erase(index)

	return {
		"success": true,
		"message": "Touch %d released at (%.1f, %.1f)%s" % [
			index, position.x, position.y,
			"" if was_held else " (index was not held; released anyway)",
		],
		"data": {
			"index": index,
			"position": {"x": position.x, "y": position.y},
			"was_held": was_held,
			"active_touches": _serialize_touches(),
		},
	}


## Drags a finger. args:
##   { "index": int = 0, "to": [x, y], "from": [x, y] optional, "steps": int = 1 }
##
## The drag starts from `from`, else from that index's tracked position; an index
## that is neither held nor given a `from` is an error rather than a drag from the
## origin. With steps > 1 the events are spread one per process frame -- N drag
## events inside a single frame is not something a real finger produces and gesture
## recognisers can legitimately reject it -- so a multi-step drag takes steps-1
## frames of wall time.
func _cmd_touch_drag(args: Dictionary) -> Dictionary:
	var index: int = int(args.get("index", 0))

	if not args.has("to"):
		return {"success": false, "message": "touch_drag requires 'to' as [x, y]"}
	var to_parsed: Variant = _parse_vector2_or_null(args["to"])
	if to_parsed == null:
		return {"success": false, "message": "'to' must be [x, y] or {\"x\": x, \"y\": y}"}
	var to_pos: Vector2 = to_parsed

	var from_pos: Vector2 = Vector2.ZERO
	if args.has("from"):
		var from_parsed: Variant = _parse_vector2_or_null(args["from"])
		if from_parsed == null:
			return {"success": false, "message": "'from' must be [x, y] or {\"x\": x, \"y\": y}"}
		from_pos = from_parsed
	elif _active_touches.has(index):
		from_pos = _active_touches[index]
	else:
		return {
			"success": false,
			"message": "Touch index %d is not held. Press it first, or pass 'from' as [x, y]." % index,
		}

	var steps: int = maxi(1, int(args.get("steps", 1)))
	var delta: float = maxf(get_process_delta_time(), 0.0001)
	var previous: Vector2 = from_pos
	# Track from the start point, so a touch_clear after a failed run still lifts it.
	_active_touches[index] = from_pos

	for step: int in range(1, steps + 1):
		var point: Vector2 = from_pos.lerp(to_pos, float(step) / float(steps))
		_dispatch_drag(index, point, point - previous, delta)
		previous = point
		_active_touches[index] = point
		if step < steps:
			await get_tree().process_frame
			delta = maxf(get_process_delta_time(), 0.0001)

	return {
		"success": true,
		"message": "Touch %d dragged (%.1f, %.1f) -> (%.1f, %.1f) in %d step%s" % [
			index, from_pos.x, from_pos.y, to_pos.x, to_pos.y, steps, "" if steps == 1 else "s",
		],
		"data": {
			"index": index,
			"from": {"x": from_pos.x, "y": from_pos.y},
			"to": {"x": to_pos.x, "y": to_pos.y},
			"steps": steps,
			"active_touches": _serialize_touches(),
		},
	}


## Lifts every tracked finger. Cheap insurance: a run that ends mid-gesture leaves
## the game holding a touch nothing will ever finish, and the next run inherits it.
func _cmd_touch_clear(_args: Dictionary) -> Dictionary:
	var released: Array = _clear_all_simulated_touches()
	return {
		"success": true,
		"message": "Released %d simulated touches" % released.size(),
		"data": {"released": released},
	}


## Reports the fingers the harness believes are down. This is the harness's own
## tracking, not a query of the OS -- it cannot see touches the harness did not send.
func _cmd_touch_list(_args: Dictionary) -> Dictionary:
	var touches: Array = _serialize_touches()
	return {
		"success": true,
		"message": "%d simulated touch%s held" % [touches.size(), "" if touches.size() == 1 else "es"],
		"data": {
			"touches": touches,
			"count": touches.size(),
			"touchscreen_available": DisplayServer.is_touchscreen_available(),
		},
	}


# --- Engine Feature Flags ---

## Forces engine-level feature flags that a game queries to decide what UI to show.
## args: { "touchscreen": bool }. The dictionary is deliberately open -- unrecognised
## keys are reported back in data["unknown"] rather than rejected, so future flags
## can be added without breaking a client.
##
## {"touchscreen": true} calls Input.set_emulate_touch_from_mouse(true). That IS the
## lever behind DisplayServer.is_touchscreen_available(): verified on Godot 4.7.1
## against both the headless and the real Windows display server, which reported
## false before the call and true after. data["touchscreen_available"] returns the
## live value so the caller can confirm it took effect on their build rather than
## trusting this comment. Two caveats:
##
##  * It is a query, not a signal. A Control that read is_touchscreen_available()
##    once in its own _ready() will not re-evaluate. Set the flag BEFORE the scene
##    that reads it loads, or call that node's own refresh method afterwards.
##  * It is real emulation: while on, mouse input in the window is also delivered as
##    touch events. That is usually what you want for a touch-UI screenshot, but it
##    means the session is no longer a faithful mouse session.
func _cmd_set_feature(args: Dictionary) -> Dictionary:
	var applied: Dictionary = {}
	var unknown: Array = []

	for key: String in args:
		match key:
			"touchscreen":
				var want: bool = bool(args[key])
				Input.set_emulate_touch_from_mouse(want)
				applied["touchscreen"] = want
			_:
				unknown.append(key)

	var data: Dictionary = {
		"applied": applied,
		"unknown": unknown,
		"touchscreen_available": DisplayServer.is_touchscreen_available(),
		"emulate_touch_from_mouse": Input.is_emulating_touch_from_mouse(),
	}

	if applied.is_empty():
		return {
			"success": false,
			"message": "No known feature flags supplied. Supported: touchscreen (bool).",
			"data": data,
		}

	return {
		"success": true,
		"message": "Applied %s. DisplayServer.is_touchscreen_available() is now %s. UI that read this flag during its own _ready() will not re-evaluate on its own." % [
			str(applied), str(data["touchscreen_available"]),
		],
		"data": data,
	}


func _cmd_input_actions(args: Dictionary) -> Dictionary:
	var include_builtin: bool = args.get("include_builtin", false)
	var actions: Array = []

	for action in InputMap.get_actions():
		var action_str: String = str(action)
		if not include_builtin and action_str.begins_with("ui_"):
			continue

		var events: Array = []
		for event in InputMap.action_get_events(action_str):
			events.append(event.as_text())

		actions.append({
			"name": action_str,
			"events": events,
			"pressed": Input.is_action_pressed(action_str),
		})

	return {
		"success": true,
		"message": "%d actions found" % actions.size(),
		"data": {"actions": actions},
	}


func _cmd_input_sequence(args: Dictionary) -> Dictionary:
	var steps: Variant = args.get("steps", [])
	if not steps is Array or steps.is_empty():
		return {"success": false, "message": "No steps provided or steps is not an array"}

	var timeout: float = args.get("timeout", 30.0)
	var sequence_id: String = str(randi())

	# Validate all steps before executing.
	for i in steps.size():
		var step: Variant = steps[i]
		if not step is Dictionary:
			return {"success": false, "message": "Step %d is not a dictionary" % i}
		var step_dict: Dictionary = step
		var step_type: String = step_dict.get("type", "")
		if step_type.is_empty():
			return {"success": false, "message": "Step %d has no type" % i}
		if step_type not in ["press", "release", "tap", "hold", "wait", "wait_frames", "screenshot", "assert", "clear", "command"]:
			return {"success": false, "message": "Step %d has unknown type: %s" % [i, step_type]}
		# Validate action exists for input steps.
		if step_type in ["press", "release", "tap", "hold"]:
			var action: String = step_dict.get("action", "")
			if action.is_empty():
				return {"success": false, "message": "Step %d (%s) has no action" % [i, step_type]}
			if not InputMap.has_action(action):
				return {"success": false, "message": "Step %d: unknown action: %s" % [i, action]}

	# Launch the async sequence.
	_execute_sequence(sequence_id, steps as Array, timeout)

	return {
		"success": true,
		"message": "Sequence %s started with %d steps" % [sequence_id, steps.size()],
		"data": {"sequence_id": sequence_id, "step_count": steps.size()},
	}


func _execute_sequence(sequence_id: String, steps: Array, timeout: float) -> void:
	var start_time: float = Time.get_unix_time_from_system()

	for i in steps.size():
		if Time.get_unix_time_from_system() - start_time > timeout:
			_write_log("input", "Sequence %s timed out at step %d" % [sequence_id, i])
			return

		var step: Dictionary = steps[i]
		match step["type"]:
			"press":
				var action: String = step["action"]
				var strength: float = step.get("strength", 1.0)
				Input.action_press(action, strength)
				_dispatch_action_event(action, true, strength)
				_active_simulated_inputs.append(action)

			"release":
				var action: String = step["action"]
				Input.action_release(action)
				_dispatch_action_event(action, false)
				_active_simulated_inputs.erase(action)

			"tap":
				var action: String = step["action"]
				var hold: float = step.get("seconds", step.get("hold", 0.0))
				var strength: float = step.get("strength", 1.0)
				Input.action_press(action, strength)
				_dispatch_action_event(action, true, strength)
				_active_simulated_inputs.append(action)
				await get_tree().create_timer(maxf(hold, get_process_delta_time())).timeout
				Input.action_release(action)
				_dispatch_action_event(action, false)
				_active_simulated_inputs.erase(action)

			"hold":
				var action: String = step["action"]
				var strength: float = step.get("strength", 1.0)
				Input.action_press(action, strength)
				_dispatch_action_event(action, true, strength)
				_active_simulated_inputs.append(action)
				await get_tree().create_timer(step["seconds"]).timeout
				Input.action_release(action)
				_dispatch_action_event(action, false)
				_active_simulated_inputs.erase(action)

			"wait":
				await get_tree().create_timer(step["seconds"]).timeout

			"screenshot":
				var filename: String = step.get("filename", "seq_%s_%d.png" % [sequence_id, i])
				_cmd_screenshot({"filename": filename})

			"assert":
				var target: Node = get_node_or_null(step["node"])
				if target == null:
					_write_log("input", "Sequence %s assert failed: node not found %s" % [sequence_id, step["node"]])
					return
				var actual: Variant = target.get(step["property"])
				var expected: Variant = step["equals"]
				var values_match: bool = false
				if typeof(actual) in [TYPE_INT, TYPE_FLOAT] and typeof(expected) in [TYPE_INT, TYPE_FLOAT]:
					values_match = is_equal_approx(float(actual), float(expected))
				else:
					values_match = str(actual) == str(expected)
				if not values_match:
					_write_log("input", "Sequence %s assert failed: %s.%s = %s, expected %s" % [
						sequence_id, step["node"], step["property"], str(actual), str(expected)
					])
					return

			"wait_frames":
				var count: int = step.get("frames", step.get("count", 1))
				for _f: int in range(count):
					await get_tree().process_frame

			"command":
				var cmd_name: String = step.get("name", "")
				if cmd_name.is_empty():
					_write_log("input", "Sequence %s step %d: command has no name" % [sequence_id, i])
					return
				var cmd_args: Dictionary = {}
				for key: String in step:
					if key not in ["type", "name", "comment"]:
						cmd_args[key] = step[key]
				# Dispatch through the registry so project-registered verbs work too.
				var action_key: String = cmd_name.replace("-", "_")
				if not _handlers.has(action_key):
					_write_log("input", "Sequence %s step %d: unknown command '%s'" % [sequence_id, i, cmd_name])
					return
				var handler: Callable = _handlers[action_key]
				var result: Variant = await handler.call(cmd_args)
				# Handlers report failure via the "success" bool (not a "status" field).
				if result is Dictionary and not (result as Dictionary).get("success", false):
					_write_log("input", "Sequence %s step %d: command '%s' failed: %s" % [
						sequence_id, i, cmd_name, (result as Dictionary).get("message", "")
					])
					return

			"clear":
				_clear_all_simulated_inputs()

	_write_log("input", "Sequence %s completed (%d steps)" % [sequence_id, steps.size()])


# --- Time Control Handlers ---

func _cmd_set_game_speed(args: Dictionary) -> Dictionary:
	var prev: float = Engine.time_scale
	var scale: float = clampf(float(args.get("scale", 1.0)), 0.0, 100.0)
	Engine.time_scale = scale

	return {
		"success": true,
		"message": "Game speed: %.1f -> %.1f" % [prev, scale],
		"data": {"previous_scale": prev, "current_scale": scale},
	}


## Advances the running game by (approximately) `seconds` of game time, so a tween or
## animation can be sampled at a chosen moment instead of wherever a real-time sleep
## happened to land. args: { "seconds": float }.
##
## READ THE LIMITS BEFORE TRUSTING A SAMPLE TAKEN THIS WAY.
##
##  * There is no manual tick. GDScript cannot drive SceneTree iterations, so there
##    is no "advance the world by exactly N seconds and stop" primitive to build on.
##    This verb runs the game at normal speed and returns once enough time has
##    passed. The tree is NOT paused and NOT stepped, despite what the name suggests.
##  * Engine.time_scale is pinned to 1.0 for the duration and restored afterwards, so
##    a leftover `set_game_speed 0.05` cannot silently stretch the interval. That
##    pinning is the part that makes repeated samples comparable.
##  * PHYSICS IS EXACT. Physics deltas are fixed at 1/physics_ticks_per_second, so
##    advancing N physics frames advances physics-driven state by exactly
##    N/physics_ticks_per_second seconds. data["physics_seconds"] is that number and
##    it is the one to trust. A Tween created with TWEEN_PROCESS_PHYSICS, or an
##    AnimationPlayer set to ANIMATION_PROCESS_PHYSICS, lands on it.
##  * PROCESS IS NOT EXACT. Tween defaults to TWEEN_PROCESS_IDLE and AnimationPlayer
##    to ANIMATION_PROCESS_IDLE; both advance by the real frame delta, which is
##    wall-clock and jittery. This verb therefore also accumulates the process deltas
##    it actually observed and reports them as data["process_seconds"]. The sample
##    lands within roughly one frame (~16 ms at 60 FPS) of the requested moment, not
##    on it. Compare process_seconds against seconds_requested rather than assuming
##    they match; for a tighter sample, drive the tween off physics.
##  * A paused tree still emits process/physics frames while nothing in the game
##    advances, so this would happily "step" a frozen game. data["tree_paused"] says
##    whether that happened -- check it before concluding the animation did nothing.
##  * The loop has a frame budget so a starved or stalled tree cannot wedge the
##    single-in-flight command bus. data["budget_exhausted"] reports it and the
##    command returns success:false.
func _cmd_step_time(args: Dictionary) -> Dictionary:
	var seconds: float = float(args.get("seconds", 0.0))
	if seconds <= 0.0:
		return {"success": false, "message": "step_time requires a positive 'seconds' value"}
	if seconds > STEP_TIME_MAX_SECONDS:
		return {
			"success": false,
			"message": "step_time refuses %.3fs; the maximum is %.1fs (the bridge serves one command at a time)" % [
				seconds, STEP_TIME_MAX_SECONDS,
			],
		}

	var ticks_per_second: int = Engine.physics_ticks_per_second
	var target_physics_frames: int = ceili(seconds * float(ticks_per_second))
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 1.0

	var start_physics_frames: int = int(Engine.get_physics_frames())
	var start_process_frames: int = int(Engine.get_process_frames())
	var start_msec: int = Time.get_ticks_msec()
	var process_seconds: float = 0.0
	# What the request should need, plus generous headroom for a loop running below
	# real time. Purely a stuck-loop guard, not a pacing mechanism.
	var frame_budget: int = target_physics_frames * 4 + 240
	var frames_spent: int = 0
	var budget_exhausted: bool = false

	while true:
		var physics_advanced: int = int(Engine.get_physics_frames()) - start_physics_frames
		# Wait for BOTH clocks: the physics one so physics-driven state advances the
		# full requested amount, the process one so idle tweens do too.
		if physics_advanced >= target_physics_frames and process_seconds >= seconds:
			break
		if frames_spent >= frame_budget:
			budget_exhausted = true
			break
		await get_tree().process_frame
		frames_spent += 1
		process_seconds += get_process_delta_time()

	var physics_frames: int = int(Engine.get_physics_frames()) - start_physics_frames
	var process_frames: int = int(Engine.get_process_frames()) - start_process_frames
	var elapsed_ms: int = Time.get_ticks_msec() - start_msec
	var tree_paused: bool = get_tree().paused
	Engine.time_scale = previous_scale

	var data: Dictionary = {
		"seconds_requested": seconds,
		"frames_advanced": physics_frames,
		"physics_frames": physics_frames,
		"target_physics_frames": target_physics_frames,
		"physics_seconds": float(physics_frames) / float(maxi(1, ticks_per_second)),
		"physics_ticks_per_second": ticks_per_second,
		"process_frames": process_frames,
		"process_seconds": process_seconds,
		"elapsed_wall_ms": elapsed_ms,
		"previous_time_scale": previous_scale,
		"restored_time_scale": Engine.time_scale,
		"tree_paused": tree_paused,
		"budget_exhausted": budget_exhausted,
	}

	var message: String = "Advanced %.4fs of physics time (%d frames @ %d Hz, exact) and %.4fs of process time (approximate, +/- one frame); requested %.4fs. time_scale pinned to 1.0 and restored to %.3f." % [
		data["physics_seconds"], physics_frames, ticks_per_second, process_seconds, seconds, previous_scale,
	]
	if tree_paused:
		message += " WARNING: get_tree().paused is true, so node processing did not actually advance."
	if budget_exhausted:
		message += " WARNING: frame budget exhausted before the target was reached -- the loop is starved."

	return {
		"success": not budget_exhausted,
		"message": message,
		"data": data,
	}


func _cmd_wait_frames(args: Dictionary) -> Dictionary:
	var count: int = int(args.get("count", 1))
	var start_time := Time.get_ticks_msec()
	for i in range(count):
		await get_tree().process_frame
	var elapsed_ms := Time.get_ticks_msec() - start_time

	return {
		"success": true,
		"message": "Waited %d frames" % count,
		"data": {"frames": count, "elapsed_ms": elapsed_ms},
	}


# --- UI Validation Helpers ---

func _get_effective_alpha(node: Node) -> float:
	var alpha: float = 1.0
	var current: Node = node
	while current != null:
		if current is CanvasItem:
			alpha *= current.modulate.a * current.self_modulate.a
		if current is CanvasLayer:
			break
		current = current.get_parent()
	return alpha


func _is_effectively_visible(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current is CanvasItem and not current.visible:
			return false
		if current is CanvasLayer:
			break
		current = current.get_parent()
	return true


func _get_control_text(node: Control) -> String:
	if node is Label:
		return node.text
	if node is Button:
		return node.text
	if node is RichTextLabel:
		return node.get_parsed_text()
	return ""


## Finds the HUD CanvasLayer by the configured `hud_layer_name`, falling back to
## the first CanvasLayer found (in the current scene, then under the root).
## Provided for extensions that need to reach the HUD generically.
func _find_hud_node() -> Node:
	var hud_name: String = _config.get("hud_layer_name", "HUD")
	var scene: Node = get_tree().current_scene
	var first_layer: Node = null

	if scene != null:
		for child in scene.get_children():
			if child is CanvasLayer:
				if child.name == hud_name:
					return child
				if first_layer == null:
					first_layer = child

	for child in get_tree().root.get_children():
		if child is CanvasLayer:
			if child.name == hud_name:
				return child
			if first_layer == null:
				first_layer = child

	return first_layer


# --- UI Validation Command Handlers ---

## Runs the UI checks over the current scene.
##
## The safe-area check (issue code "ui_outside_safe_area") reads `safe_area_inset`
## from devtools_config.json, overridable per call via args["safe_area_inset"]. It is
## SKIPPED ENTIRELY when the inset is all zeros -- with a zero inset it would only
## restate checks 1 and 5, and an existing project must see exactly the findings it
## saw before this check existed.
func _cmd_validate_ui(args: Dictionary) -> Dictionary:
	var issues: Array = []
	var interactive_controls: Array = []
	var vp: Vector2 = Vector2(get_tree().root.size)

	var inset: Dictionary = _resolve_safe_area_inset(args)
	var check_safe_area: bool = inset["left"] != 0.0 or inset["top"] != 0.0 \
		or inset["right"] != 0.0 or inset["bottom"] != 0.0
	var safe_rect: Rect2 = Rect2(
		inset["left"],
		inset["top"],
		maxf(0.0, vp.x - inset["left"] - inset["right"]),
		maxf(0.0, vp.y - inset["top"] - inset["bottom"]))

	_validate_ui_recursive(get_tree().current_scene, vp, issues, interactive_controls, safe_rect, check_safe_area)

	# Check for overlapping interactive controls
	var overlaps: Array = _check_interactive_overlaps(interactive_controls)
	for overlap: Dictionary in overlaps:
		issues.append({
			"severity": "warning",
			"code": "interactive_overlap",
			"message": "Interactive controls overlap: '%s' and '%s' (overlap area: %.0fpx)" % [
				overlap["node_a"], overlap["node_b"], overlap["overlap_area"],
			],
		})

	return {
		"success": issues.is_empty(),
		"message": "%d UI issues found" % issues.size() if not issues.is_empty() else "No UI issues found",
		"data": {
			"issues": issues,
			"safe_area_checked": check_safe_area,
			"safe_area_inset": inset,
			"safe_area_rect": {
				"x": safe_rect.position.x,
				"y": safe_rect.position.y,
				"w": safe_rect.size.x,
				"h": safe_rect.size.y,
			},
		},
	}


## Reads the safe-area inset (pixels trimmed off each viewport edge) from args, else
## from `safe_area_inset` in devtools_config.json, else zero. Always returns all four
## edges as floats so callers need no further guarding.
func _resolve_safe_area_inset(args: Dictionary) -> Dictionary:
	var inset: Dictionary = {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	var source: Variant = args.get("safe_area_inset", _config.get("safe_area_inset", {}))
	if source is Dictionary:
		var source_dict: Dictionary = source
		for edge: String in ["left", "top", "right", "bottom"]:
			var value: Variant = source_dict.get(edge, 0.0)
			if _is_number(value):
				inset[edge] = float(value)
	return inset


func _validate_ui_recursive(node: Node, vp: Vector2, issues: Array, interactive_controls: Array = [], safe_rect: Rect2 = Rect2(), check_safe_area: bool = false) -> void:
	if node is Control and _is_effectively_visible(node):
		var control: Control = node as Control
		var rect: Rect2 = control.get_global_rect()

		# Collect interactive controls for overlap detection
		if (control is Button or control is TextureButton or control is LinkButton) and control.visible:
			interactive_controls.append({"path": str(control.get_path()), "rect": rect})

		# Check 1: Viewport overflow
		if rect.position.x + rect.size.x > vp.x or rect.position.y + rect.size.y > vp.y:
			issues.append({
				"severity": "warning",
				"code": "ui_overflow",
				"message": "%s '%s' extends past viewport (rect: %.0f,%.0f -> %.0f,%.0f, viewport: %.0fx%.0f)" % [
					control.get_class(), control.name,
					rect.position.x, rect.position.y,
					rect.position.x + rect.size.x, rect.position.y + rect.size.y,
					vp.x, vp.y,
				],
			})

		# Check 2: Zero-size visible
		if control.size.x == 0.0 or control.size.y == 0.0:
			issues.append({
				"severity": "warning",
				"code": "ui_zero_size",
				"message": "%s '%s' is visible but has zero size (%.0fx%.0f)" % [
					control.get_class(), control.name, control.size.x, control.size.y,
				],
			})

		# Check 3: Fully transparent
		var effective_alpha: float = _get_effective_alpha(control)
		if effective_alpha == 0.0:
			issues.append({
				"severity": "info",
				"code": "ui_transparent",
				"message": "%s '%s' is visible but fully transparent (effective alpha: %.2f)" % [
					control.get_class(), control.name, effective_alpha,
				],
			})

		# Check 4: Text overflow (Label only, autowrap disabled)
		if control is Label and control.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var font: Font = control.get_theme_font("font")
			if font != null:
				var font_size: int = control.get_theme_font_size("font_size")
				if font_size <= 0:
					font_size = control.get_theme_default_font_size()
				var text_width: float = font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				if text_width > control.size.x and control.size.x > 0.0:
					var display_text: String = control.text
					if display_text.length() > 50:
						display_text = display_text.substr(0, 47) + "..."
					issues.append({
						"severity": "warning",
						"code": "ui_text_overflow",
						"message": "%s '%s' text '%s' exceeds width (text: %.0fpx, label: %.0fpx)" % [
							control.get_class(), control.name, display_text, text_width, control.size.x,
						],
					})

		# Check 5: Negative position
		if rect.position.x < 0.0 or rect.position.y < 0.0:
			issues.append({
				"severity": "warning",
				"code": "ui_negative_pos",
				"message": "%s '%s' has negative position (%.0f, %.0f)" % [
					control.get_class(), control.name, rect.position.x, rect.position.y,
				],
			})

		# Check 6: Button text overflow
		if control is Button and control.text.length() > 0:
			var btn_font: Font = control.get_theme_font("font")
			var btn_font_size: int = control.get_theme_font_size("font_size")
			if btn_font:
				var btn_text_width: float = btn_font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, btn_font_size).x
				var padding: float = 16.0
				if btn_text_width + padding > control.size.x and control.size.x > 0.0:
					issues.append({
						"severity": "warning",
						"code": "button_text_overflow",
						"message": "Button '%s' text '%s' (%.0fpx) exceeds button width (%.0fpx)" % [
							control.name, control.text, btn_text_width, control.size.x,
						],
					})

		# Check 7: Minimum tap target size for interactive controls
		if (control is Button or control is TextureButton or control is LinkButton) and control.visible:
			var min_tap: float = 40.0
			if control.size.x < min_tap or control.size.y < min_tap:
				issues.append({
					"severity": "warning",
					"code": "small_tap_target",
					"message": "Interactive control '%s' size %.0fx%.0f below minimum %.0fx%.0f" % [
						control.name, control.size.x, control.size.y, min_tap, min_tap,
					],
				})

		# Check 8: Container child position consistency
		# If a node is inside a BoxContainer (HBox/VBox) with layout_mode 2,
		# its position should be within the container's bounds
		if node.get_parent() is BoxContainer:
			var parent_container: BoxContainer = node.get_parent() as BoxContainer
			var parent_rect: Rect2 = parent_container.get_global_rect()
			var node_rect: Rect2 = control.get_global_rect()
			var path: String = str(control.get_path())
			# Check if child extends beyond parent bounds (layout corruption)
			if node_rect.position.x < parent_rect.position.x - 2.0:
				issues.append({
					"severity": "warning",
					"code": "container_layout_drift",
					"message": "Node '%s' position (%.0f) is left of parent container (%.0f) - possible layout corruption" % [
						path, node_rect.position.x, parent_rect.position.x,
					],
				})
			if node_rect.end.x > parent_rect.end.x + 2.0:
				issues.append({
					"severity": "warning",
					"code": "container_layout_drift",
					"message": "Node '%s' extends past parent container right edge (%.0f > %.0f) - possible layout corruption" % [
						path, node_rect.end.x, parent_rect.end.x,
					],
				})

		# Check 9: Safe-area inset. Only interactive or text-bearing controls are
		# judged -- a full-bleed background legitimately covers the trimmed edges, and
		# flagging it would bury the findings that matter. Skipped wholesale when the
		# inset is all zeros, so an existing project sees no new findings.
		if check_safe_area and control.visible:
			var is_interactive: bool = control is Button or control is TextureButton or control is LinkButton
			var carries_text: bool = not _get_control_text(control).is_empty()
			if (is_interactive or carries_text) and not safe_rect.encloses(rect):
				issues.append({
					"severity": "warning",
					"code": "ui_outside_safe_area",
					"message": "%s '%s' falls outside the safe area (rect: %.0f,%.0f -> %.0f,%.0f, safe area: %.0f,%.0f -> %.0f,%.0f)" % [
						control.get_class(), control.name,
						rect.position.x, rect.position.y, rect.end.x, rect.end.y,
						safe_rect.position.x, safe_rect.position.y, safe_rect.end.x, safe_rect.end.y,
					],
				})

	for child in node.get_children():
		_validate_ui_recursive(child, vp, issues, interactive_controls, safe_rect, check_safe_area)


func _cmd_get_ui_snapshot(_args: Dictionary) -> Dictionary:
	var vp: Vector2 = Vector2(get_tree().root.size)
	var elements: Array = []
	_snapshot_ui_recursive(get_tree().current_scene, vp, elements)

	return {
		"success": true,
		"message": "%d UI elements captured" % elements.size(),
		"data": {
			"viewport": {"width": int(vp.x), "height": int(vp.y)},
			"elements": elements,
		},
	}


func _snapshot_ui_recursive(node: Node, vp: Vector2, elements: Array) -> void:
	if node is Control:
		var control: Control = node as Control
		var eff_visible: bool = _is_effectively_visible(control)
		var eff_alpha: float = _get_effective_alpha(control)

		if eff_visible or eff_alpha > 0.0:
			var rect: Rect2 = control.get_global_rect()
			elements.append({
				"name": str(control.name),
				"type": control.get_class(),
				"path": str(control.get_path()),
				"global_rect": {
					"x": rect.position.x,
					"y": rect.position.y,
					"w": rect.size.x,
					"h": rect.size.y,
				},
				"visible": eff_visible,
				"modulate_a": eff_alpha,
				"text": _get_control_text(control),
				"in_viewport": rect.position.x >= 0.0 and rect.position.y >= 0.0
					and rect.position.x + rect.size.x <= vp.x
					and rect.position.y + rect.size.y <= vp.y,
			})

	for child in node.get_children():
		_snapshot_ui_recursive(child, vp, elements)


func _cmd_get_node_bounds(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	if node_path.is_empty():
		return {"success": false, "message": "No node_path provided"}

	var node: Node = get_node_or_null(node_path)
	if node == null:
		return {"success": false, "message": "Node not found: %s" % node_path}

	if not node is Control:
		return {"success": false, "message": "Node is not a Control: %s" % node_path}

	var control: Control = node as Control
	var vp: Vector2 = Vector2(get_tree().root.size)
	var rect: Rect2 = control.get_global_rect()

	return {
		"success": true,
		"message": "Bounds for %s" % control.name,
		"data": {
			"name": str(control.name),
			"type": control.get_class(),
			"path": str(control.get_path()),
			"global_rect": {
				"x": rect.position.x,
				"y": rect.position.y,
				"w": rect.size.x,
				"h": rect.size.y,
			},
			"visible": _is_effectively_visible(control),
			"modulate_a": _get_effective_alpha(control),
			"text": _get_control_text(control),
			"in_viewport": rect.position.x >= 0.0 and rect.position.y >= 0.0
				and rect.position.x + rect.size.x <= vp.x
				and rect.position.y + rect.size.y <= vp.y,
		},
	}


# --- UI Baseline & Diff ---

func _cmd_save_ui_baseline(_args: Dictionary) -> Dictionary:
	var snapshot: Array = _capture_ui_snapshot_flat()
	var json_str: String = JSON.stringify(snapshot, "\t")
	var file: FileAccess = FileAccess.open("user://ui_baseline.json", FileAccess.WRITE)
	if file == null:
		return {"success": false, "message": "Failed to write baseline file"}
	file.store_string(json_str)
	file.close()
	return {
		"success": true,
		"message": "Baseline saved with %d nodes" % snapshot.size(),
		"data": {"nodes_saved": snapshot.size()},
	}


func _cmd_ui_snapshot_diff(_args: Dictionary) -> Dictionary:
	if not FileAccess.file_exists("user://ui_baseline.json"):
		return {"success": false, "message": "No baseline found. Run save_ui_baseline first."}

	var file: FileAccess = FileAccess.open("user://ui_baseline.json", FileAccess.READ)
	var baseline_text: String = file.get_as_text()
	file.close()
	var baseline: Variant = JSON.parse_string(baseline_text)
	if baseline == null or not baseline is Array:
		return {"success": false, "message": "Failed to parse baseline JSON"}

	var current: Array = _capture_ui_snapshot_flat()
	var diffs: Array = []
	var threshold: float = 5.0

	# Build lookup by node path
	var baseline_map: Dictionary = {}
	for node_data: Dictionary in baseline:
		baseline_map[node_data["path"]] = node_data

	for node_data: Dictionary in current:
		var path: String = node_data["path"]
		if baseline_map.has(path):
			var base: Dictionary = baseline_map[path]
			var dx: float = absf(node_data["x"] - base["x"])
			var dy: float = absf(node_data["y"] - base["y"])
			var dw: float = absf(node_data["w"] - base["w"])
			var dh: float = absf(node_data["h"] - base["h"])
			if dx > threshold or dy > threshold or dw > threshold or dh > threshold:
				diffs.append({
					"path": path,
					"type": "changed",
					"position_delta": [dx, dy],
					"size_delta": [dw, dh],
					"baseline": {"x": base["x"], "y": base["y"], "w": base["w"], "h": base["h"]},
					"current": {"x": node_data["x"], "y": node_data["y"], "w": node_data["w"], "h": node_data["h"]},
				})
		else:
			diffs.append({"path": path, "type": "new_node"})

	for path: String in baseline_map:
		var found: bool = false
		for node_data: Dictionary in current:
			if node_data["path"] == path:
				found = true
				break
		if not found:
			diffs.append({"path": path, "type": "removed_node"})

	return {
		"success": diffs.size() == 0,
		"message": "%d diffs found" % diffs.size() if diffs.size() > 0 else "No layout drift detected",
		"data": {
			"status": "pass" if diffs.size() == 0 else "drift_detected",
			"diffs": diffs,
		},
	}


func _capture_ui_snapshot_flat() -> Array:
	var elements: Array = []
	var scene: Node = get_tree().current_scene
	if scene:
		_snapshot_flat_recursive(scene, elements)
	return elements


func _snapshot_flat_recursive(node: Node, elements: Array) -> void:
	if node is Control and _is_effectively_visible(node):
		var control: Control = node as Control
		var rect: Rect2 = control.get_global_rect()
		elements.append({
			"path": str(control.get_path()),
			"name": str(control.name),
			"type": control.get_class(),
			"x": rect.position.x,
			"y": rect.position.y,
			"w": rect.size.x,
			"h": rect.size.y,
		})
	for child in node.get_children():
		_snapshot_flat_recursive(child, elements)


# --- UI Overlap Detection ---

func _check_interactive_overlaps(controls: Array) -> Array:
	var overlaps: Array = []
	for i in range(controls.size()):
		for j in range(i + 1, controls.size()):
			var rect_a: Rect2 = controls[i]["rect"]
			var rect_b: Rect2 = controls[j]["rect"]
			if rect_a.intersects(rect_b):
				var intersection: Rect2 = rect_a.intersection(rect_b)
				overlaps.append({
					"type": "interactive_overlap",
					"node_a": controls[i]["path"],
					"node_b": controls[j]["path"],
					"overlap_area": intersection.get_area(),
					"overlap_rect": {"x": intersection.position.x, "y": intersection.position.y, "w": intersection.size.x, "h": intersection.size.y},
				})
	return overlaps


# --- Utility Functions ---

func _load_validator() -> GDScript:
	var validator_path: String = _config.get("validator_script", "")
	if validator_path.is_empty() or not ResourceLoader.exists(validator_path):
		return null
	return load(validator_path) as GDScript


func _serialize_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL:
			return null
		TYPE_BOOL:
			return value
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return value
		TYPE_STRING:
			return value
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_RECT2:
			return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key in value:
				result[str(key)] = _serialize_variant(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				result.append(_serialize_variant(item))
			return result
		_:
			return str(value)


func _write_log(category: String, message: String, data: Variant = null) -> void:
	var entry: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"frame": Engine.get_process_frames(),
		"category": category,
		"message": message,
	}
	if data != null:
		entry["data"] = data

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		# File may not exist yet; create it.
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.close()


func _find_all_scenes(path: String) -> Array[String]:
	var scenes: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return scenes

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name == ".godot" or file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path: String = path.path_join(file_name)
		if dir.current_is_dir():
			scenes.append_array(_find_all_scenes(full_path))
		elif file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
			scenes.append(full_path)

		file_name = dir.get_next()
	dir.list_dir_end()

	return scenes


func _clear_all_simulated_inputs() -> Array[String]:
	var cleared: Array[String] = _active_simulated_inputs.duplicate()
	for action in cleared:
		Input.action_release(action)
		_dispatch_action_event(action, false)
	_active_simulated_inputs.clear()
	return cleared


## Mirrors _clear_all_simulated_inputs() for touch. Hooked into input_clear,
## touch_clear and _exit_tree so a run cannot leave phantom fingers down: an
## unreleased touch is a gesture the game is still waiting to complete, and it
## outlives the run that started it.
func _clear_all_simulated_touches() -> Array:
	var released: Array = _serialize_touches()
	for entry: Dictionary in released:
		var position: Dictionary = entry["position"]
		_dispatch_touch(int(entry["index"]), Vector2(position["x"], position["y"]), false)
	_active_touches.clear()
	return released


func _serialize_touches() -> Array:
	var out: Array = []
	var indexes: Array = _active_touches.keys()
	indexes.sort()
	for index: int in indexes:
		var position: Vector2 = _active_touches[index]
		out.append({"index": index, "position": {"x": position.x, "y": position.y}})
	return out


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


## Parses [x, y] or {"x": ..., "y": ...} into a Vector2. Returns null -- not a zero
## vector -- on anything else, so a malformed argument is rejected loudly rather than
## silently reinterpreted as the top-left corner of the screen.
func _parse_vector2_or_null(value: Variant) -> Variant:
	if value is Array:
		var arr: Array = value
		if arr.size() >= 2 and _is_number(arr[0]) and _is_number(arr[1]):
			return Vector2(float(arr[0]), float(arr[1]))
	elif value is Dictionary:
		var dict: Dictionary = value
		if dict.has("x") and dict.has("y") and _is_number(dict["x"]) and _is_number(dict["y"]):
			return Vector2(float(dict["x"]), float(dict["y"]))
	return null


func _clear_stale_files() -> void:
	if FileAccess.file_exists(COMMANDS_PATH):
		DirAccess.remove_absolute(_commands_abs_path)
	if FileAccess.file_exists(RESULTS_PATH):
		DirAccess.remove_absolute(_results_abs_path)
