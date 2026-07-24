@tool
extends SceneTree

# Combined linter: UID check for .tscn/.tres and scene configuration warnings.
# Run headless: godot --headless --script res://tools/lint_project.gd
# With args:    godot --headless --script res://tools/lint_project.gd -- --all --json

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scenes: PackedStringArray = []
	var json := false
	var fail_on_warn := false
	var uids_only := false
	var warnings_only := false

	for i in args.size():
		match args[i]:
			"--scene":
				if i + 1 < args.size():
					scenes.append(args[i + 1])
			"--all":
				scenes = _find_all_scenes("res://")
			"--json":
				json = true
			"--fail-on-warn":
				fail_on_warn = true
			"--uids-only":
				uids_only = true
			"--warnings-only":
				warnings_only = true

	if scenes.is_empty():
		scenes = _find_all_scenes("res://")

	var results := {
		"uids": {
			"mismatches": [],
			"had_error": false
		},
		"warnings": {
			"by_scene": [],
			"had_warn": false,
			"had_error": false
		}
	}

	# UID check over all .tscn/.tres in project, unless warnings-only
	if not warnings_only:
		var uid_ok := true
		for path in _scan(["tscn", "tres"]):
			var ok_one: bool = _check_uid_one(path, results["uids"])
			if not ok_one:
				uid_ok = false
		if not uid_ok:
			results["uids"]["had_error"] = true

	# Scene configuration warnings for selected scenes, unless uids-only
	if not uids_only:
		for p in scenes:
			var entry = {"scene": p}
			var ps: PackedScene = load(p)
			if ps == null:
				entry["warnings"] = [{"path": ".", "messages": ["Scene failed to load (may need import cache)"]}]
				results["warnings"]["had_warn"] = true
				results["warnings"]["by_scene"].append(entry)
				continue

			var state := ps.get_state()
			var warnings: Array = []
			if state != null:
				var node_count := state.get_node_count()
				var path_set := {}
				for i in range(node_count):
					var np: NodePath = state.get_node_path(i, true)
					path_set[String(np)] = true

				for ni in range(node_count):
					var node_abs_path := String(state.get_node_path(ni, true))
					var prop_cnt := state.get_node_property_count(ni)
					for pidx in range(prop_cnt):
						var p_name := String(state.get_node_property_name(ni, pidx))
						var p_val: Variant = state.get_node_property_value(ni, pidx)
						if _is_nodepath_like_property(p_name, p_val):
							var p_str := String(p_val)
							if p_str == "":
								warnings.append({"path": node_abs_path, "messages": ["SceneState: NodePath-like property '%s' is empty" % p_name]})
							else:
								var resolved: String = _resolve_relative_nodepath(node_abs_path, p_str)
								var unresolved := (resolved != "") and (not _path_set_has_relaxed(path_set, resolved))
								if unresolved:
									var msg := "SceneState: '%s' NodePath unresolved: %s (-> %s)" % [p_name, p_str, resolved]
									var warn := {"path": node_abs_path, "messages": [msg]}
									warnings.append(warn)

			if warnings.size() > 0:
				results["warnings"]["had_warn"] = true
			entry["warnings"] = warnings
			results["warnings"]["by_scene"].append(entry)

	# Output
	if json:
		print(JSON.stringify(results, "  "))
	else:
		if not warnings_only:
			if results["uids"]["mismatches"].is_empty():
				print("UIDs: OK")
			else:
				for m in results["uids"]["mismatches"]:
					var umsg := "%s: uid mismatch for %s -> file has %s, expected %s" % [m.path, m.res_path, m.file_uid, m.expected_uid]
					printerr(umsg)
		if not uids_only:
			for r in results["warnings"]["by_scene"]:
				if "error" in r:
					printerr("%s: %s" % [r.scene, r.error])
				elif r.warnings.is_empty():
					print("%s: OK" % r.scene)
				else:
					for w in r.warnings:
						print("%s | %s: %s" % [r.scene, w.path, ", ".join(w.messages)])

	# Exit code
	var exit_code := 0
	var had_uid_errors: bool = (not warnings_only) and results["uids"]["had_error"]
	var had_warn_errors: bool = (not uids_only) and (results["warnings"]["had_error"] or (fail_on_warn and results["warnings"]["had_warn"]))
	if had_uid_errors or had_warn_errors:
		exit_code = 1
	quit(exit_code)


# --- UID check ---
func _scan(exts: Array[String]) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open("res://")
	if dir:
		files += _scan_dir(dir, exts)
	return files


func _scan_dir(dir: DirAccess, exts: Array[String]) -> Array[String]:
	var out: Array[String] = []
	dir.list_dir_begin()
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if dir.current_is_dir():
			if f != ".godot":
				out += _scan_dir(DirAccess.open(dir.get_current_dir() + "/" + f), exts)
		else:
			for e in exts:
				if f.ends_with("." + e):
					out.append(dir.get_current_dir() + "/" + f)
	dir.list_dir_end()
	return out


func _check_uid_one(p: String, out) -> bool:
	var ok := true
	var text := FileAccess.get_file_as_string(p)
	if text == "":
		out["mismatches"].append({"path": p, "res_path": "", "file_uid": "", "expected_uid": "<failed to read>"})
		return false
	for line in text.split("\n"):
		if line.begins_with("[ext_resource "):
			var path := _extract(line, "path")
			var uid := _extract(line, "uid")
			if path != "" and uid != "":
				var id: int = ResourceLoader.get_resource_uid(path)
				if id != ResourceUID.INVALID_ID:
					var expected := ResourceUID.id_to_text(id)
					if uid != expected:
						out["mismatches"].append({"path": p, "res_path": path, "file_uid": uid, "expected_uid": expected})
						ok = false
	return ok


func _extract(line: String, key: String) -> String:
	var m := RegEx.new()
	m.compile(key + "=\"([^\"]+)\"")
	var r := m.search(line)
	return r.get_string(1) if r != null else ""


func _find_all_scenes(root_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var d := DirAccess.open(root_path)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := d.get_current_dir() + "/" + name
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_find_all_scenes(full))
		elif name.ends_with(".tscn") or name.ends_with(".scn"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
	return out


func _resolve_relative_nodepath(base_abs: String, rel: String) -> String:
	if rel.begins_with("/"):
		return _normalize_against_root(base_abs, rel.trim_prefix("/"))
	var base_had_dot := base_abs.begins_with("./")
	var base_abs_work := base_abs
	if base_had_dot:
		base_abs_work = base_abs.substr(2)
	var base_parts := base_abs_work.split("/")
	if base_parts.size() > 0:
		base_parts.remove_at(base_parts.size() - 1)
	var rel_parts := rel.split("/")
	for part in rel_parts:
		if part == "." or part == "":
			continue
		elif part == "..":
			if base_parts.size() == 0:
				return ""
			base_parts.remove_at(base_parts.size() - 1)
		else:
			base_parts.append(part)
	var joined := "/".join(base_parts)
	return _normalize_against_root(base_abs, joined)


func _normalize_against_root(base_abs: String, abs_path: String) -> String:
	if abs_path == "":
		return ""
	var base_had_dot := base_abs.begins_with("./") or base_abs == "."
	if base_had_dot and not abs_path.begins_with("./") and not abs_path.contains("/"):
		return "./" + abs_path
	return abs_path


func _path_set_has_relaxed(path_set: Dictionary, path: String) -> bool:
	if path_set.has(path):
		return true
	if path.begins_with("./"):
		var alt := path.substr(2)
		if path_set.has(alt):
			return true
	else:
		var alt2 := "./" + path
		if path_set.has(alt2):
			return true
	return false


func _is_nodepath_like_property(name: String, value: Variant) -> bool:
	if typeof(value) == TYPE_NODE_PATH:
		return true
	if typeof(value) == TYPE_STRING:
		var lname := name.to_lower()
		if lname.ends_with("_path") or lname.ends_with("path"):
			return true
	return false
