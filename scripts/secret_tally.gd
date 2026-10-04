class_name SecretTally
extends RefCounted

## The run's secrets: which ones the player claimed (Globals.secret_found), and how
## many the run's levels hold. Kinds: "wall" (a cracked wall's orb taken) and "news"
## (a newspaper stand read). ScoreSystem owns one per run.
##
## Totals are DERIVED from the level files (every node running a kind's script), never
## typed in: add a crack to a building scene and the card's "a/b" follows.

## Kind -> the script every secret of that kind runs.
const KIND_SCRIPTS := {
	"wall": "res://scripts/crack.gd",
	"news": "res://scripts/interactive_mailbox.gd",
}

## kind -> {id: true}. Ids are node paths, so a stand read twice counts once.
var _found: Dictionary = {}

static var _totals_cache: Dictionary = {}


## Count `id` under `kind`. True only the first time; unknown kinds are ignored.
func record(kind: String, id: String) -> bool:
	if not KIND_SCRIPTS.has(kind):
		return false
	var seen: Dictionary = _found.get_or_add(kind, {})
	if seen.has(id):
		return false
	seen[id] = true
	return true


func count(kind: String) -> int:
	return (_found.get(kind, {}) as Dictionary).size()


func found_total() -> int:
	var n := 0
	for kind in _found:
		n += count(kind)
	return n


## {kind: found} for every kind, zeros included.
func counts() -> Dictionary:
	var out := {}
	for kind in KIND_SCRIPTS:
		out[kind] = count(kind)
	return out


func clear() -> void:
	_found.clear()


## {kind: how many} across `scene_paths`, nested instances included. Cached: the
## level files do not change while the game runs.
static func totals_in(scene_paths: Array) -> Dictionary:
	var key := ",".join(PackedStringArray(scene_paths))
	if _totals_cache.has(key):
		return (_totals_cache[key] as Dictionary).duplicate()
	var totals := {}
	for kind in KIND_SCRIPTS:
		totals[kind] = 0
	for path in scene_paths:
		var packed := load(path) as PackedScene
		if packed != null:
			_count_state(packed.get_state(), totals)
	_totals_cache[key] = totals
	return totals.duplicate()


static func _count_state(state: SceneState, totals: Dictionary) -> void:
	for i in state.get_node_count():
		var sub := state.get_node_instance(i)
		if sub != null:
			# An instance node repeats its scene root's script; the recursion counts it.
			_count_state(sub.get_state(), totals)
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) != &"script":
				continue
			var script := state.get_node_property_value(i, p) as Script
			if script == null:
				continue
			for kind in KIND_SCRIPTS:
				if script.resource_path == KIND_SCRIPTS[kind]:
					totals[kind] += 1
