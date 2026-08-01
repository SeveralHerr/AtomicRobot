@tool
extends SceneTree

# Combined linter: UID check, duplicate resource-id check, and scene
# configuration warnings for the files under the configured scan_root.
#
# Run headless: godot --headless --path . --script res://tools/lint_project.gd
# With args:    godot --headless --path . --script res://tools/lint_project.gd -- --all --json
#
# Flags (everything after the bare `--` is read via OS.get_cmdline_user_args()):
#   --scene <path>        Lint only this scene (repeatable).
#   --all                 Lint every scene under scan_root (this is the default).
#   --json                Emit the full result dictionary as JSON.
#   --uids-only           Skip the scene-configuration pass.
#   --warnings-only       Skip the UID / duplicate-id pass.
#   --strict              Count warnings towards the exit code.
#   --fail-on-warn        Alias for --strict, kept for older callers.
#   --baseline-write <p>  Write the current finding keys to <p> as JSON, exit 0.
#   --baseline <p>        Compare against a written baseline: findings print as
#                         NEW or PRE-EXISTING, and only NEW ones affect the exit code.
#   --find-orphans        Opt-in heuristic scan for public functions nothing but
#                         the tests calls. Warnings only - never fails the run,
#                         not even under --strict.
#
# Exit codes. This script always calls quit() with its own finding count, so the
# code is the lint verdict and never Godot's shutdown noise about leaked RIDs or
# ObjectDB instances:
#   0  no errors
#   1  lint errors found (or warnings, under --strict)
#   2  the linter could not run: unreadable/invalid config, unopenable scan_root,
#      missing flag argument, or an unreadable/invalid baseline file
#
# Baseline workflow - two commands, no git shell-out, so it cannot hang:
#   1. at the merge-base:  godot ... lint_project.gd -- --baseline-write lint_baseline.json
#   2. on the working tree: godot ... lint_project.gd -- --baseline lint_baseline.json
# A finding key is "file|rule|subject" and deliberately carries no line numbers,
# so a finding survives an unrelated edit to the same file.
#
# Windows note: the plain (non-console) Godot .exe writes nothing to a PowerShell
# console. Redirect to a file and read it back. Every line this script emits goes
# to stdout via print(), so one redirect captures the whole report.

const CONFIG_PATH: String = "res://addons/godot_selftest/devtools_config.json"
const DEFAULT_SCAN_ROOT: String = "res://"
const DEFAULT_TEST_DIR: String = "res://test/unit"

const EXIT_OK: int = 0
const EXIT_LINT_ERRORS: int = 1
const EXIT_LINTER_FAILED: int = 2

# Every finding: {file, rule, subject, severity, message, advisory}
# "advisory" findings are reported but never counted, even under --strict.
var _findings: Array[Dictionary] = []
var _ident_re: RegEx = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scenes: PackedStringArray = []
	var all_scenes := false
	var json := false
	var strict := false
	var uids_only := false
	var warnings_only := false
	var find_orphans := false
	var baseline_read := ""
	var baseline_write := ""
	var arg_error := ""

	for i in args.size():
		match args[i]:
			"--scene":
				if i + 1 < args.size():
					scenes.append(args[i + 1])
				else:
					arg_error = "--scene needs a scene path"
			"--all":
				all_scenes = true
			"--json":
				json = true
			"--fail-on-warn", "--strict":
				strict = true
			"--uids-only":
				uids_only = true
			"--warnings-only":
				warnings_only = true
			"--find-orphans":
				find_orphans = true
			"--baseline":
				if i + 1 < args.size():
					baseline_read = args[i + 1]
				else:
					arg_error = "--baseline needs a path to a baseline JSON file"
			"--baseline-write":
				if i + 1 < args.size():
					baseline_write = args[i + 1]
				else:
					arg_error = "--baseline-write needs an output path"

	if arg_error != "":
		_abort(arg_error)
		return

	# Config: a missing file is fine (defaults apply), a malformed one is not.
	var config := {}
	if FileAccess.file_exists(CONFIG_PATH):
		var cfg_text := FileAccess.get_file_as_string(CONFIG_PATH)
		var parsed: Variant = JSON.parse_string(cfg_text)
		if typeof(parsed) != TYPE_DICTIONARY:
			_abort("%s is not a valid JSON object" % CONFIG_PATH)
			return
		config = parsed

	var scan_root := _norm_path(str(config.get("scan_root", DEFAULT_SCAN_ROOT)))
	if scan_root == "":
		scan_root = DEFAULT_SCAN_ROOT
	var test_dir := _norm_path(str(config.get("test_dir", DEFAULT_TEST_DIR)))
	if DirAccess.open(scan_root) == null:
		_abort("scan_root '%s' could not be opened" % scan_root)
		return

	if all_scenes or scenes.is_empty():
		scenes = _find_all_scenes(scan_root)

	var results := {
		"uids": {
			"mismatches": [],
			"had_error": false
		},
		"warnings": {
			"by_scene": [],
			"had_warn": false,
			"had_error": false
		},
		"duplicate_ids": []
	}

	# UID + duplicate-id check over all .tscn/.tres in scan_root, unless warnings-only
	if not warnings_only:
		var uid_ok := true
		for path in _scan(scan_root, ["tscn", "tres"]):
			var ok_one: bool = _check_uid_one(path, results["uids"])
			if not ok_one:
				uid_ok = false
			_check_duplicate_ids(path, results["duplicate_ids"])
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
				_add_finding(p, "scene_load_failed", "", "warning", "Scene failed to load (may need import cache)")
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
							var subject := "%s.%s" % [node_abs_path, p_name]
							if p_str == "":
								var empty_msg := "SceneState: NodePath-like property '%s' is empty" % p_name
								warnings.append({"path": node_abs_path, "messages": [empty_msg]})
								_add_finding(p, "nodepath_empty", subject, "warning", empty_msg)
							else:
								var resolved: String = _resolve_relative_nodepath(node_abs_path, p_str)
								var unresolved := (resolved != "") and (not _path_set_has_relaxed(path_set, resolved))
								if unresolved:
									var msg := "SceneState: '%s' NodePath unresolved: %s (-> %s)" % [p_name, p_str, resolved]
									var warn := {"path": node_abs_path, "messages": [msg]}
									warnings.append(warn)
									_add_finding(p, "nodepath_unresolved", subject, "warning", msg)

			if warnings.size() > 0:
				results["warnings"]["had_warn"] = true
			entry["warnings"] = warnings
			results["warnings"]["by_scene"].append(entry)

	# Opt-in orphan scan. Advisory only: it is a heuristic and never gates a run.
	if find_orphans:
		results["orphans"] = _find_orphans(scan_root, test_dir)

	# Baseline: split findings into what the baseline already knew about and what is new.
	var baseline_keys := {}
	if baseline_read != "":
		var loaded: Variant = _load_baseline(baseline_read)
		if loaded == null:
			return
		baseline_keys = loaded
	var new_findings: Array[Dictionary] = []
	var old_findings: Array[Dictionary] = []
	for f in _findings:
		if baseline_keys.has(_finding_key(f)):
			old_findings.append(f)
		else:
			new_findings.append(f)

	# --baseline-write records the whole finding set and never fails the run.
	if baseline_write != "":
		_write_baseline(baseline_write)
		return

	# Output
	if json:
		results["findings"] = _findings
		if baseline_read != "":
			results["baseline"] = {"path": baseline_read, "new": new_findings, "pre_existing": old_findings}
		print(JSON.stringify(results, "  "))
	else:
		if not warnings_only:
			if results["uids"]["mismatches"].is_empty():
				print("UIDs: OK")
			else:
				for m in results["uids"]["mismatches"]:
					print("%s: uid mismatch for %s -> file has %s, expected %s" % [m.path, m.res_path, m.file_uid, m.expected_uid])
			for d in results["duplicate_ids"]:
				print("ERROR: %s: %s" % [d.path, d.message])
		if not uids_only:
			for r in results["warnings"]["by_scene"]:
				if "error" in r:
					print("%s: %s" % [r.scene, r.error])
				elif r.warnings.is_empty():
					print("%s: OK" % r.scene)
				else:
					for w in r.warnings:
						print("%s | %s: %s" % [r.scene, w.path, ", ".join(w.messages)])
		if find_orphans:
			for o in results["orphans"]:
				print("WARN: %s: %s" % [o.file, o.message])
		if baseline_read != "":
			_print_baseline_groups(baseline_read, baseline_keys.size(), new_findings, old_findings)

	# Exit code: driven by this script's own findings, never by Godot's shutdown noise.
	var counted: Array[Dictionary] = new_findings if baseline_read != "" else _findings
	var errors := 0
	var warns := 0
	for f in counted:
		if f["advisory"]:
			continue
		if f["severity"] == "error":
			errors += 1
		else:
			warns += 1

	var exit_code := EXIT_OK
	if errors > 0 or (strict and warns > 0):
		exit_code = EXIT_LINT_ERRORS
	if not json:
		var scope := "new " if baseline_read != "" else ""
		print("lint: %d %serror(s), %d %swarning(s) -> exit %d" % [errors, scope, warns, scope, exit_code])
	quit(exit_code)


# --- Findings ---
func _add_finding(file: String, rule: String, subject: String, severity: String, message: String, advisory: bool = false) -> void:
	_findings.append({
		"file": _norm_path(file),
		"rule": rule,
		"subject": subject,
		"severity": severity,
		"message": message,
		"advisory": advisory,
	})


# Stable across unrelated edits: no line numbers, only file + rule + subject.
func _finding_key(f: Dictionary) -> String:
	return "%s|%s|%s" % [f["file"], f["rule"], f["subject"]]


func _abort(reason: String) -> void:
	print("LINTER ERROR: %s" % reason)
	print("lint: could not run -> exit %d" % EXIT_LINTER_FAILED)
	quit(EXIT_LINTER_FAILED)


# --- Baseline ---
func _write_baseline(path: String) -> void:
	var keys: Array[String] = []
	for f in _findings:
		var k := _finding_key(f)
		if not keys.has(k):
			keys.append(k)
	keys.sort()
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		_abort("could not write baseline to '%s' (error %d)" % [path, FileAccess.get_open_error()])
		return
	out.store_string(JSON.stringify(keys, "  "))
	out.close()
	print("baseline: wrote %d finding key(s) to %s" % [keys.size(), path])
	quit(EXIT_OK)


# Returns a Dictionary used as a key set, or null after aborting.
func _load_baseline(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_abort("baseline file '%s' not found (write one first with --baseline-write)" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY:
		_abort("baseline file '%s' is not a JSON array of finding keys" % path)
		return null
	var keys := {}
	for k in parsed:
		keys[str(k)] = true
	return keys


func _print_baseline_groups(path: String, key_count: int, new_findings: Array[Dictionary], old_findings: Array[Dictionary]) -> void:
	print("")
	print("baseline: %s (%d key(s))" % [path, key_count])
	if new_findings.is_empty():
		print("NEW: none")
	for f in new_findings:
		print("NEW | %s" % _format_finding(f))
	if old_findings.is_empty():
		print("PRE-EXISTING: none")
	for f in old_findings:
		print("PRE-EXISTING | %s" % _format_finding(f))


func _format_finding(f: Dictionary) -> String:
	var tag: String = "ADVISORY" if f["advisory"] else String(f["severity"]).to_upper()
	return "[%s] %s: %s" % [tag, f["file"], f["message"]]


# --- UID check ---
func _scan(root: String, exts: Array[String]) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(root)
	if dir:
		files += _scan_dir(dir, exts)
	return files


func _scan_dir(dir: DirAccess, exts: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if dir == null:
		return out
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
					out.append(_norm_path(dir.get_current_dir() + "/" + f))
	dir.list_dir_end()
	return out


func _check_uid_one(p: String, out) -> bool:
	var ok := true
	var text := FileAccess.get_file_as_string(p)
	if text == "":
		out["mismatches"].append({"path": p, "res_path": "", "file_uid": "", "expected_uid": "<failed to read>"})
		_add_finding(p, "read_failed", "", "error", "failed to read file")
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
						_add_finding(p, "uid_mismatch", path, "error", "uid mismatch for %s -> file has %s, expected %s" % [path, uid, expected])
						ok = false
	return ok


# --- Duplicate resource ids ---
# Text-level on purpose: two branches each adding an [ext_resource] id to the same
# scene produce a duplicate that loads without complaint and binds the wrong
# resource, so loading the scene would not reveal it.
func _check_duplicate_ids(p: String, out: Array) -> void:
	var text := FileAccess.get_file_as_string(p)
	if text == "":
		return  # already reported by the UID pass
	var seen := {}
	var lines := text.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		var kind := ""
		if line.begins_with("[ext_resource "):
			kind = "ext_resource"
		elif line.begins_with("[sub_resource "):
			kind = "sub_resource"
		else:
			continue
		var id := _extract_id(line)
		if id == "":
			continue
		# ExtResource() and SubResource() are separate lookups, so ids collide per kind.
		var key := "%s %s" % [kind, id]
		if not seen.has(key):
			seen[key] = {"kind": kind, "id": id, "lines": []}
		seen[key]["lines"].append(i + 1)
	for key in seen:
		var hit: Dictionary = seen[key]
		var at: Array = hit["lines"]
		if at.size() < 2:
			continue
		var at_text: PackedStringArray = []
		for n in at:
			at_text.append(str(n))
		var where := ", ".join(at_text)
		var msg := "duplicate %s id \"%s\" (lines %s) - binds the wrong resource silently" % [hit["kind"], hit["id"], where]
		out.append({"path": p, "kind": hit["kind"], "id": hit["id"], "lines": at, "message": msg})
		_add_finding(p, "duplicate_resource_id", key, "error", msg)


# --- Orphan API scan (heuristic, opt-in, advisory) ---
# Flags public funcs whose only callers outside their own file live in tests.
# Known false positives: signal callbacks wired in code, virtual overrides,
# call()/callv() by a computed name, and @export/inspector-assigned hooks.
func _find_orphans(scan_root: String, test_dir: String) -> Array:
	var out: Array = []
	var gd_files := _scan(scan_root, ["gd"])
	var identifiers := {}      # file -> {identifier: true}
	var declared_in := {}      # func name -> Array[String] of declaring files
	var decl_re := RegEx.new()
	decl_re.compile("func\\s+([A-Za-z][A-Za-z0-9_]*)\\s*\\(")

	for f in gd_files:
		var text := FileAccess.get_file_as_string(f)
		identifiers[f] = _identifier_set(text)
		if _is_test_path(f, test_dir):
			continue  # test-only funcs are called by name from the runner
		for m in decl_re.search_all(text):
			var fn := m.get_string(1)
			if not declared_in.has(fn):
				declared_in[fn] = []
			if not declared_in[fn].has(f):
				declared_in[fn].append(f)

	# Names mentioned anywhere in a scene/resource file: signal connections, etc.
	var scene_names := {}
	for s in _scan(scan_root, ["tscn", "tres"]):
		for name in _identifier_set(FileAccess.get_file_as_string(s)):
			scene_names[name] = true

	var names: Array = declared_in.keys()
	names.sort()
	for fn in names:
		var owners: Array = declared_in[fn]
		if owners.size() != 1:
			continue  # duplicated name: an override or interface pattern, not an orphan
		if scene_names.has(fn):
			continue
		var owner: String = owners[0]
		var test_callers := 0
		var live_callers := 0
		for f in gd_files:
			if f == owner:
				continue
			if not identifiers[f].has(fn):
				continue
			if _is_test_path(f, test_dir):
				test_callers += 1
			else:
				live_callers += 1
		if live_callers > 0:
			continue
		var msg := ""
		if test_callers > 0:
			msg = "%s() is referenced only from tests (%d file(s)) - heuristic, may be a callback or called by name" % [fn, test_callers]
		else:
			msg = "%s() has no reference outside its own file - heuristic, may be a callback or called by name" % fn
		out.append({"file": owner, "func": fn, "test_callers": test_callers, "message": msg})
		_add_finding(owner, "orphan_api", fn, "warning", msg, true)
	return out


func _identifier_set(text: String) -> Dictionary:
	var out := {}
	if text == "":
		return out
	if _ident_re == null:
		_ident_re = RegEx.new()
		_ident_re.compile("[A-Za-z_][A-Za-z0-9_]*")
	for m in _ident_re.search_all(text):
		out[m.get_string(0)] = true
	return out


func _is_test_path(p: String, test_dir: String) -> bool:
	var n := _norm_path(p)
	if test_dir != "" and n.begins_with(test_dir):
		return true
	return n.contains("/test/") or n.contains("/tests/") or n.get_file().begins_with("test_")


# --- Shared helpers ---
func _norm_path(p: String) -> String:
	return p.replace("res:///", "res://")


func _extract(line: String, key: String) -> String:
	var m := RegEx.new()
	# \b so that looking for `id=` does not match inside `uid=`.
	m.compile("\\b" + key + "=\"([^\"]+)\"")
	var r := m.search(line)
	return r.get_string(1) if r != null else ""


# Godot 4 writes id="1_abc"; older/hand-edited files may use a bare id=1.
func _extract_id(line: String) -> String:
	var quoted := _extract(line, "id")
	if quoted != "":
		return quoted
	var m := RegEx.new()
	m.compile("\\bid=([^\\s\\]]+)")
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
		var full := _norm_path(d.get_current_dir() + "/" + name)
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
