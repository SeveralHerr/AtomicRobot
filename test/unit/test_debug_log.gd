extends RefCounted

# Debug console lines go through Utils.debug_log, which is silent unless a debug
# build runs with `-- --verbose-logs`. A bare print() on a slow stdout (pipe,
# browser devtools, a recording) stalled 33-47% of hit frames by 20-35 ms on the
# cabinet, so none may land in game code. tools/ (autoplay summaries) is exempt.

var _T

const ROOT := "res://scripts"
const HELPER := "res://scripts/autoload/utils.gd"
const ALLOWED_IN_HELPER := 1

static var _bare_print := RegEx.create_from_string("(^|[^A-Za-z0-9_.])print\\(")


func _gd_files(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(d), out)


func _bare_prints(path: String) -> Array[String]:
	var hits: Array[String] = []
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var code := lines[i].strip_edges()
		if code.begins_with("#"):
			continue
		if _bare_print.search(code):
			hits.append("%s:%d  %s" % [path, i + 1, code])
	return hits


func test_no_bare_print_in_game_scripts() -> String:
	var files: Array[String] = []
	_gd_files(ROOT, files)
	if files.size() < 50:
		return "scanned only %d scripts under %s" % [files.size(), ROOT]
	var hits: Array[String] = []
	var helper_hits := 0
	for f in files:
		var found := _bare_prints(f)
		if f == HELPER:
			helper_hits = found.size()
		else:
			hits.append_array(found)
	var r: String = _T.assert_eq(helper_hits, ALLOWED_IN_HELPER, "Utils.debug_log keeps its one print()")
	if r != "":
		return r
	return _T.assert_eq("\n".join(hits), "", "bare print() calls; use Utils.debug_log")


func test_the_scan_sees_a_bare_print() -> String:
	var r: String = _T.assert_true(_bare_print.search("\tprint(\"dead af\")") != null, "tab-indented print")
	if r != "":
		return r
	r = _T.assert_true(_bare_print.search("if x: print(x)") != null, "inline print")
	if r != "":
		return r
	r = _T.assert_true(_bare_print.search("_fill_print(text)") == null, "a *_print( helper is not print")
	if r != "":
		return r
	return _T.assert_true(_bare_print.search("Utils.debug_log(x)") == null, "debug_log is allowed")


func test_debug_log_is_off_without_the_flag() -> String:
	if OS.get_cmdline_user_args().has("--verbose-logs"):
		return ""
	var r: String = _T.assert_false(Utils.verbose_logs, "verbose_logs defaults off")
	if r != "":
		return r
	return _T.assert_eq(Utils.debug_log("Enemy state ", "ChasePlayerState"), "", "debug_log prints nothing")


func test_debug_log_joins_its_parts_when_on() -> String:
	var was: bool = Utils.verbose_logs
	Utils.verbose_logs = true
	var line: String = Utils.debug_log("Health: ", 3, " (", 1.5, ")")
	Utils.verbose_logs = was
	return _T.assert_eq(line, "Health: 3 (1.5)", "parts joined like print()")
