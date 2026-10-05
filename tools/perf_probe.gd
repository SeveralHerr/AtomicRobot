extends SceneTree

## Perf probe (skills/godot-perf-probe/SKILL.md): boots the project's main scene (autoloads incl. Autoplay run as usual)
## and logs one CSV row per frame: wall frame time + engine monitors + where the player is.
## Run uncapped: --fixed-fps 60 --disable-vsync, so wall time == real frame cost.

var rows := PackedStringArray()
var last_us := 0
var out_path := ""
var vp_rid: RID
var added: Dictionary = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--perf-out")
	out_path = args[i + 1] if i != -1 else "perf.csv"
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	vp_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	rows.append("frame,t_ms,frame_us,proc_ms,phys_ms,rcpu_ms,rgpu_ms,draw_calls,prims,objects,nodes,orphans,bodies,pairs,scene,px,mem_mb,ts,delta,added")
	last_us = Time.get_ticks_usec()
	node_added.connect(_on_added)


func _on_added(n: Node) -> void:
	var k := n.get_class() if n.scene_file_path == "" else n.scene_file_path.get_file()
	if n.get_script() and n.scene_file_path == "":
		k = (n.get_script() as Script).resource_path.get_file()
	added[k] = int(added.get(k, 0)) + 1


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var ft := now - last_us
	last_us = now
	var scene: String = String(current_scene.name) if current_scene else ""
	var px := ""
	var p: Node = get_first_node_in_group("player")
	if p is Node2D:
		px = str(int(p.global_position.x))
	rows.append("%d,%d,%d,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%d,%d,%d,%d,%s,%s,%.1f,%.3f,%.4f,%s" % [
		Engine.get_process_frames(), Time.get_ticks_msec(), ft,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(vp_rid),
		RenderingServer.viewport_get_measured_render_time_gpu(vp_rid),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),
		scene, px, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Engine.time_scale, _delta, "|".join(added.keys().map(func(k): return "%s*%d" % [k, added[k]]))])
	added.clear()
	return false


func _finalize() -> void:
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(rows))
	print("PERF rows=%d -> %s" % [rows.size(), out_path])
