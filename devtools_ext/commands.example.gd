extends RefCounted

## Project DevTools command extension — WORKED REFERENCE (not installed by default).
##
## This file is a template to COPY FROM. To use it, move/rename it to
## `res://devtools_ext/commands.gd` (the path in devtools_config.json ->
## "extension_script"), then adapt the verbs to your game's nodes, groups, and
## autoloads. Nothing here is game-specific enough to run as-is — the node paths,
## group names, scene paths, and autoload names are placeholders you must change.
##
## How it hooks in:
##   The godot_selftest core (addons/godot_selftest/dev_tools.gd) instantiates
##   this script once and calls `register_commands(dev)` AFTER registering its
##   own generic verbs, so re-registering a generic action string overrides it
##   (last-writer-wins). Hold the passed `dev` Node — it is the DevTools autoload
##   and your live handle into the running scene tree.
##
## Handler contract (every verb):
##   func(args: Dictionary) -> Dictionary
##   returning EXACTLY { "success": bool, "message": String, "data": Dictionary }
##
## Reaching the running game from a handler (via the stored `_dev` Node):
##   var tree: SceneTree = _dev.get_tree()
##   var scene: Node = tree.current_scene                 # active scene root
##   var actors: Array = tree.get_nodes_in_group("actor") # nodes by group
##   var mgr: Node = _dev.get_node_or_null("/root/GameManager")  # an autoload
##
## Verb naming: the file bus uses underscores ("spawn_entity"); the Python client
## addresses the same verb with hyphens ("cmd spawn-entity"). The core normalizes
## hyphens to underscores when dispatching sequence "command" steps, so register
## with underscores.

var _dev: Node


func register_commands(dev: Node) -> void:
	_dev = dev
	_dev.register_command("spawn_entity", _cmd_spawn_entity)
	_dev.register_command("get_actor_state", _cmd_get_actor_state)
	_dev.register_command("reset_session", _cmd_reset_session)
	_dev.register_command("revive_actor", _cmd_revive_actor)
	# Not a verb: merged into EVERY response as "status". See _status().
	_dev.register_status_provider(_status)


## Liveness facts attached to every reply the bridge sends.
##
## The failure this prevents: once the thing under test is dead or frozen, every
## gameplay query keeps returning well-formed zeros — nothing moving, no state
## changing — which is indistinguishable from a genuine clean result. Runs have been
## read as "the feature is broken" when the real answer was "your player died forty
## samples ago". Putting liveness on every response makes that self-announcing.
##
## Keep the payload tiny; it rides on every single reply.
func _status(_args: Dictionary) -> Dictionary:
	var actor: Node = _dev.get_tree().get_first_node_in_group("player")
	if actor == null:
		return {"actor": "absent"}
	# Duck-typed so this stays portable across projects.
	var dead: bool = actor.get("is_dead") == true
	return {"actor": "dead" if dead else "alive"}


## Undo a death so a run can continue instead of being relaunched.
##
## Restoring a health value is usually NOT enough: the death flag and the state
## machine outlive it, so the actor stays frozen and every later reading is garbage.
## Clear the flag AND leave the death state, and prefer an invulnerability toggle for
## long observation runs — re-writing health each sample loses the race to any hit
## that lands between two writes.
func _cmd_revive_actor(args: Dictionary) -> Dictionary:
	var actor: Node = _dev.get_tree().get_first_node_in_group("player")
	if actor == null:
		return {"success": false, "message": "No node in group 'player'", "data": {}}
	actor.set("is_dead", false)
	if args.has("health"):
		actor.set("health", int(args["health"]))
	if args.has("invulnerable"):
		actor.set("god_mode", bool(args["invulnerable"]))
	# Adapt to your own state machine; without this the actor revives but stays parked
	# in its death state, still playing the death animation.
	var sm: Variant = actor.get("state_machine")
	if sm != null and sm.has_method("change_state"):
		sm.change_state(args.get("state", "IdleState"))
	return {"success": true, "message": "revived", "data": {}}


## Instantiate a scene and add it to the current scene root.
## Example bus call:   {"action": "spawn_entity", "args": {"scene": "res://scenes/enemy.tscn", "x": 100, "y": -50}}
## Example CLI call:    python3 tools/devtools.py cmd spawn-entity --args '{"scene":"res://scenes/enemy.tscn","x":100}'
func _cmd_spawn_entity(args: Dictionary) -> Dictionary:
	var scene_path: String = args.get("scene", "")
	if scene_path.is_empty():
		return {"success": false, "message": "No 'scene' path provided"}
	if not ResourceLoader.exists(scene_path):
		return {"success": false, "message": "Scene not found: %s" % scene_path}

	var scene_root: Node = _dev.get_tree().current_scene
	if scene_root == null:
		return {"success": false, "message": "No current scene"}

	var packed: PackedScene = load(scene_path) as PackedScene
	var entity: Node = packed.instantiate()

	# Position it if it is a 2D node and coordinates were supplied.
	if entity is Node2D:
		var x: float = args.get("x", 0.0)
		var y: float = args.get("y", 0.0)
		(entity as Node2D).position = Vector2(x, y)

	scene_root.add_child(entity)

	return {
		"success": true,
		"message": "Spawned %s" % scene_path,
		"data": {"name": str(entity.name), "path": str(entity.get_path())},
	}


## Read state off the first node in a group.
## Example bus call:   {"action": "get_actor_state", "args": {"group": "player", "properties": ["position", "health"]}}
func _cmd_get_actor_state(args: Dictionary) -> Dictionary:
	var group: String = args.get("group", "")
	if group.is_empty():
		return {"success": false, "message": "No 'group' provided"}

	var members: Array = _dev.get_tree().get_nodes_in_group(group)
	if members.is_empty():
		return {"success": false, "message": "No nodes in group: %s" % group}

	var actor: Node = members[0]
	var wanted: Array = args.get("properties", [])
	var state: Dictionary = {}
	for prop: Variant in wanted:
		var prop_name: String = str(prop)
		state[prop_name] = str(actor.get(prop_name))

	return {
		"success": true,
		"message": "State for '%s' in group '%s'" % [actor.name, group],
		"data": {"path": str(actor.get_path()), "state": state},
	}


## Call methods on an autoload to reset gameplay state.
## Example bus call:   {"action": "reset_session", "args": {}}
## Adapt the autoload name ("GameManager") and method names to your project.
func _cmd_reset_session(_args: Dictionary) -> Dictionary:
	var manager: Node = _dev.get_node_or_null("/root/GameManager")
	if manager == null:
		return {"success": false, "message": "Autoload /root/GameManager not found"}

	# Duck-type: only call methods that actually exist so this stays portable.
	if manager.has_method("reset"):
		manager.reset()
	elif manager.has_method("reset_session"):
		manager.reset_session()
	else:
		return {"success": false, "message": "GameManager has no reset()/reset_session() method"}

	return {
		"success": true,
		"message": "Session reset via GameManager",
		"data": {},
	}
