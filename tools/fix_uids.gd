@tool
extends SceneTree

# Rewrites stale uid="uid://..." references in [ext_resource ...] lines of .tscn/.tres
# files to the authoritative UID reported by ResourceLoader (same source of truth as
# tools/lint_project.gd). Run after reimports/upgrades leave scenes pointing at old UIDs:
#   godot --headless --path . --script res://tools/fix_uids.gd
# Add "-- --dry-run" to preview without writing.

func _initialize() -> void:
	var dry_run := OS.get_cmdline_user_args().has("--dry-run")
	var fixed_files := 0
	var fixed_refs := 0

	for path in _scan("res://", ["tscn", "tres"]):
		var text := FileAccess.get_file_as_string(path)
		if text == "":
			continue
		var lines := text.split("\n")
		var changed := false
		for i in lines.size():
			var line := lines[i]
			if not line.begins_with("[ext_resource "):
				continue
			var res_path := _extract(line, "path")
			var uid := _extract(line, "uid")
			if res_path == "" or uid == "":
				continue
			var id: int = ResourceLoader.get_resource_uid(res_path)
			if id == ResourceUID.INVALID_ID:
				continue
			var expected := ResourceUID.id_to_text(id)
			if uid != expected:
				lines[i] = line.replace('uid="%s"' % uid, 'uid="%s"' % expected)
				print("%s: %s %s -> %s" % [path, res_path, uid, expected])
				changed = true
				fixed_refs += 1
		if changed and not dry_run:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string("\n".join(lines))
			f.close()
			fixed_files += 1

	print("Fixed %d references in %d files%s" % [fixed_refs, fixed_files, " (dry run, nothing written)" if dry_run else ""])
	quit(0)


func _scan(root: String, exts: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var f := dir.get_next()
		if f == "":
			break
		var full := dir.get_current_dir() + "/" + f
		if dir.current_is_dir():
			if f != ".godot":
				out += _scan(full, exts)
		else:
			for e in exts:
				if f.ends_with("." + e):
					out.append(full)
	dir.list_dir_end()
	return out


func _extract(line: String, key: String) -> String:
	var m := RegEx.new()
	m.compile(key + "=\"([^\"]+)\"")
	var r := m.search(line)
	return r.get_string(1) if r != null else ""
