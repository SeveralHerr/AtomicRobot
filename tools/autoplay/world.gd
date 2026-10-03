extends RefCounted

## Perception: reads the live scene tree into the plain snapshot brain.gd decides on.
## Kept separate from the brain so the brain stays pure and unit testable. Scene
## walks (hearts, boss door) are cached per scene instance: a full-tree search every
## physics frame is the one cost here that scales with level size.

const HEART_SCRIPT := "res://scripts/atomic_heart_pickup.gd"
const BOSS_ENTER_SCRIPT := "res://scripts/final_boss_enter.gd"
## Only enemies this close (px, horizontal) are reported; the rest are off screen.
const SEE_RANGE := 1400.0


static func player(tree: SceneTree) -> Player:
	return tree.get_first_node_in_group("player") as Player


static func scene_path(tree: SceneTree) -> String:
	return tree.current_scene.scene_file_path if tree.current_scene else ""


var _scene_id: int = 0
var _hearts: Array[Node] = []
var _doors: Array[Node] = []


func snapshot(tree: SceneTree, t: float, dt: float) -> Dictionary:
	var snap := {"t": t, "dt": dt, "player": {}, "enemies": [], "hearts": [], "pickups": [], "goal_x": INF,
		"scene_id": tree.current_scene.get_instance_id() if tree.current_scene else 0}
	var p := player(tree)
	if p == null or not p.is_inside_tree():
		return snap
	snap["player"] = player_info(p)
	var px := p.global_position.x
	for e in tree.get_nodes_in_group("enemies"):
		if e is Enemy and not e.is_dead and absf(e.global_position.x - px) <= SEE_RANGE:
			snap["enemies"].append({"x": e.global_position.x, "y": e.global_position.y,
				"lane": e.lane, "locked": e.lane_locked, "kind": e.get_script().resource_path.get_file().get_basename()})
	for pk in tree.get_nodes_in_group("powerup_pickups"):
		if pk is Node2D and not pk.get("_collected"):
			snap["pickups"].append({"x": pk.global_position.x, "y": pk.global_position.y, "lane": pk.get("lane")})
	var scene := tree.current_scene
	if scene:
		_refresh_cache(scene)
		for n in _hearts:
			if is_instance_valid(n) and not n.get("is_collected"):
				snap["hearts"].append({"x": n.global_position.x, "y": n.global_position.y})
		snap["goal_x"] = goal_x(scene, _doors)
	return snap


func _refresh_cache(scene: Node) -> void:
	if scene.get_instance_id() == _scene_id:
		return
	_scene_id = scene.get_instance_id()
	_hearts = find_by_script(scene, HEART_SCRIPT)
	_doors = find_by_script(scene, BOSS_ENTER_SCRIPT)


static func player_info(p: Player) -> Dictionary:
	var st: Variant = p.state_machine.current_state if p.state_machine else null
	return {
		"x": p.global_position.x, "y": p.global_position.y, "lane": p.current_lane,
		"hp": p.health, "max_hp": Player.max_health(), "dead": p.is_dead or st is DeadState,
		"state": state_name(st), "grounded": p.is_grounded(), "facing": p.last_dir,
		"changing_lane": p.is_changing_lane, "lanes": p.lanes_active(), "on_street": p.is_on_street(),
	}


static func state_name(st: Variant) -> String:
	if st == null:
		return ""
	var s: Script = st.get_script()
	return s.get_global_name() if s and s.get_global_name() != "" else s.resource_path.get_file().get_basename()


## Where "advance" walks to: the boss-door trigger in the street level, the boss
## room's entrance trigger / the boss itself in the boss room. INF = keep going right.
static func goal_x(scene: Node, doors: Array[Node]) -> float:
	for n in doors:
		if not is_instance_valid(n):
			continue
		var area: Node2D = n.get_node_or_null("Area2D")
		return (area if area else n as Node2D).global_position.x
	var trigger := scene.get("entrance_trigger") as Node2D
	for boss in scene.get_tree().get_nodes_in_group("enemies"):
		if boss is FinalBoss and not boss.is_dead:
			return boss.global_position.x
	if trigger and not scene.get("intro_played"):
		return trigger.global_position.x
	return INF


static func find_by_script(root: Node, path: String) -> Array[Node]:
	var out: Array[Node] = []
	_collect(root, path, out)
	return out


static func _collect(n: Node, path: String, out: Array[Node]) -> void:
	var s: Script = n.get_script()
	if s and s.resource_path == path:
		out.append(n)
	for c in n.get_children():
		_collect(c, path, out)
