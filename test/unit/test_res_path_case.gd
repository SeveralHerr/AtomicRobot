extends RefCounted

# Every res:// path written in a script or scene matches the file's real case.
# Windows opens "res://Sounds/x.ogg" from sounds/ without complaint; the Linux CI
# export can't, and three such preloads failed 66 tests and blocked a deploy.

var _T

const ROOTS := ["res://scripts", "res://scenes"]
const EXTS := ["gd", "tscn", "tres"]


static func _source_files(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in EXTS:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_source_files(dir.path_join(d), out)


## True when every segment of `path` exists with exactly this spelling.
static func _exact_case(path: String) -> bool:
	var dir := "res://"
	var parts := path.trim_prefix("res://").split("/")
	for i in parts.size():
		var last := i == parts.size() - 1
		var names := DirAccess.get_files_at(dir) if last else DirAccess.get_directories_at(dir)
		if not (parts[i] in names):
			return false
		dir = dir.path_join(parts[i])
	return true


func test_res_paths_match_file_case() -> String:
	var files: Array[String] = []
	for root in ROOTS:
		_source_files(root, files)
	var re := RegEx.create_from_string("res://[^\"'\\s)]+\\.[A-Za-z0-9]+")
	var bad: Array[String] = []
	for f in files:
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			var path := m.get_string()
			# Only paths that resolve case-insensitively: a missing file is another bug.
			if FileAccess.file_exists(path) and not _exact_case(path):
				bad.append("%s -> %s" % [f, path])
	return _T.assert_eq(bad.size(), 0, "case-mismatched res:// paths (break on Linux): %s" % [bad])
