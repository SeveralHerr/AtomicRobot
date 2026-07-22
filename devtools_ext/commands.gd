extends RefCounted

## Project DevTools command extension (STUB).
##
## The godot_selftest core (addons/godot_selftest/dev_tools.gd) instantiates this
## script once at startup and calls `register_commands(dev)` AFTER it has
## registered all of its generic verbs. Register your project's own bus verbs
## here. Because the core loads this extension last, re-registering a generic
## action string (e.g. "screenshot") overrides the generic handler
## (last-writer-wins).
##
## Contract for every handler:
##   func(args: Dictionary) -> Dictionary
##   returning EXACTLY { "success": bool, "message": String, "data": Dictionary }
##
## Reaching the running game from a handler:
##   var tree: SceneTree = dev.get_tree()
##   var scene: Node = tree.current_scene              # the active scene root
##   var actors: Array = tree.get_nodes_in_group("...") # nodes by group
##   var mgr: Node = dev.get_node_or_null("/root/GameManager")  # an autoload
##
## The `dev` Node passed to register_commands() is the DevTools autoload itself,
## so it is a live handle into the scene tree — keep a reference to it.
##
## See commands.example.gd for a fuller worked reference (spawn-entity,
## get-actor-state, reset-session). Copy patterns from there as you grow this
## file. Verbs are addressed over the bus with underscores ("example_ping") and
## via the Python client with hyphens ("cmd example-ping").

var _dev: Node


func register_commands(dev: Node) -> void:
	_dev = dev
	# Register one trivial example verb. Delete it and add your own.
	_dev.register_command("example_ping", _cmd_example_ping)


func _cmd_example_ping(_args: Dictionary) -> Dictionary:
	return {
		"success": true,
		"message": "example",
		"data": {},
	}
