extends RefCounted

# The autoplay recorder counts Globals.secret_found per kind (one per id) and the
# distinct headlines read, so a scenario can expect "secret_news == 5" and
# "headlines == 5".

var _T

const RECORDER := preload("res://tools/autoplay/recorder.gd")
const STAND_SCENE := preload("res://scenes/interactive_mailbox.tscn")

var _rec: Node
var _nodes: Array[Node] = []


func setup() -> void:
	_rec = RECORDER.new()
	_tree().root.add_child(_rec)


func teardown() -> void:
	_rec.free()
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_secrets_count_once_per_id() -> String:
	Globals.secret_found.emit("wall", "/root/A")
	Globals.secret_found.emit("wall", "/root/A")
	Globals.secret_found.emit("wall", "/root/B")
	var m: Dictionary = _rec.metrics(_tree())
	var r: String = _T.assert_eq(m["secret_walls"], 2, "two walls, one repeat ignored")
	if r != "":
		return r
	return _T.assert_eq(m["secret_news"], 0, "no stands read")


func test_read_stand_logs_its_headline() -> String:
	var s: Node = STAND_SCENE.instantiate()
	_tree().root.add_child(s)
	_nodes.append(s)
	s._show_notification()
	var m: Dictionary = _rec.metrics(_tree())
	var r: String = _T.assert_eq([m["secret_news"], m["headlines"]], [1, 1], "one stand, one headline")
	if r != "":
		return r
	var ev: Dictionary = _rec.events.back()
	return _T.assert_eq(ev.get("headline", ""), s.notification_label.text, "event names the headline")
