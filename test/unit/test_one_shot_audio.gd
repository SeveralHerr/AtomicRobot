extends RefCounted

## SecretFx.play_once is a one-shot: its player frees itself on `finished`. Footstep
## files import with looping on (the player's run cycle needs it), and a looping stream
## never finishes, so the door mouths' crumble (wall) and rustle (bush) played on, and
## stacked, until the level unloaded. Player report: "constant breaking sound when
## nothing is on screen". The looping set is derived from the sound imports.

var _T

var _host: Node


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func teardown() -> void:
	if is_instance_valid(_host):
		_host.free()
	_host = null


static func _loops(stream: AudioStream) -> bool:
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	return "loop" in stream and bool(stream.get("loop"))


## Every sound under res://sounds that imports with looping on.
static func _looping_sounds() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at("res://sounds"):
		if not f.ends_with(".import"):
			continue
		var path := "res://sounds/" + f.trim_suffix(".import")
		if not ResourceLoader.exists(path):
			continue
		var s := load(path) as AudioStream
		if s != null and _loops(s):
			out.append(path)
	return out


func test_the_looping_set_includes_the_door_mouth_sounds() -> String:
	var paths := _looping_sounds()
	var r: String = _T.assert_true("res://sounds/422762__kierankeegan__footsteps_stone_4.wav" in paths, "wall crumble loops: %s" % [paths])
	if r != "":
		return r
	return _T.assert_true("res://sounds/Retro FootStep Grass 01.wav" in paths, "bush rustle loops: %s" % [paths])


func test_play_once_never_loops_a_looping_sound() -> String:
	_host = Node.new()
	_tree().root.add_child(_host)
	for path in _looping_sounds():
		var stream := load(path) as AudioStream
		SecretFx.play_once(_host, stream)
		var player := _host.get_child(_host.get_child_count() - 1) as AudioStreamPlayer
		var r: String = _T.assert_false(_loops(player.stream), "%s plays once" % path)
		if r != "":
			return r
		r = _T.assert_true(_loops(stream), "%s still loops for its other users (footsteps)" % path)
		if r != "":
			return r
	return ""


func test_play_once_reuses_one_copy_per_sound() -> String:
	var stream := load("res://sounds/422762__kierankeegan__footsteps_stone_4.wav") as AudioStream
	return _T.assert_true(SecretFx.one_shot(stream) == SecretFx.one_shot(stream), "no duplicate per chip")


func test_play_once_passes_a_one_shot_sound_through() -> String:
	var stream := load("res://sounds/Unlock.wav") as AudioStream
	var r: String = _T.assert_false(_loops(stream), "fixture is a one-shot")
	if r != "":
		return r
	return _T.assert_true(SecretFx.one_shot(stream) == stream, "no copy needed")
