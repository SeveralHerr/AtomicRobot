extends RefCounted

# Newspaper stands (scripts/interactive_mailbox.gd). Each stand used to pick
# randi() % 5 on its own, so a run past all five stands showed the same headline
# twice. They now draw from one shuffle bag, and reading a stand is a secret
# (Globals.secret_found "news"), reported once per stand.

var _T

const STAND_SCENE := preload("res://scenes/interactive_mailbox.tscn")

var _nodes: Array[Node] = []
var _found: Array = []


func setup() -> void:
	_found.clear()
	Globals.secret_found.connect(_on_secret)


func teardown() -> void:
	Globals.secret_found.disconnect(_on_secret)
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _on_secret(kind: String, id: String) -> void:
	_found.append([kind, id])


func _stands(n: int) -> Array:
	var out := []
	for i in n:
		var s: Node = STAND_SCENE.instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(s)
		_nodes.append(s)
		out.append(s)
	return out


func _read_all(stands: Array) -> Array:
	var seen := []
	for s in stands:
		s._show_notification()
		seen.append(s.notification_label.text)
	return seen


func _fresh_run(rng_seed: int) -> void:
	seed(rng_seed)
	var script: Variant = STAND_SCENE.instantiate()
	script.get_script().reset_headline_bag()
	script.free()


func test_five_stands_show_five_different_headlines() -> String:
	for rng_seed in [1, 2, 3, 4, 5]:
		_fresh_run(rng_seed)
		var seen := _read_all(_stands(5))
		var distinct := {}
		for t in seen:
			distinct[t] = true
		if distinct.size() != 5:
			return "seed %d: %d distinct headlines in 5 stands: %s" % [rng_seed, distinct.size(), seen]
	return ""


func test_headline_order_is_seeded() -> String:
	_fresh_run(42)
	var a := _read_all(_stands(5))
	_fresh_run(42)
	var b := _read_all(_stands(5))
	return _T.assert_eq(b, a, "same seed, same headlines (autoplay replays)")


func test_reading_a_stand_reports_one_news_secret() -> String:
	var s: Node = _stands(1)[0]
	s._show_notification()
	s._show_notification()  # read again after the cooldown
	var r: String = _T.assert_eq(_found.size(), 1, "one secret per stand")
	if r != "":
		return r
	return _T.assert_eq(_found[0], ["news", str(s.get_path())], "kind news, id = node path")


func test_each_stand_is_its_own_secret() -> String:
	for s in _stands(2):
		s._show_notification()
	var r: String = _T.assert_eq(_found.size(), 2, "two stands, two secrets")
	if r != "":
		return r
	return _T.assert_true(_found[0][1] != _found[1][1], "ids differ per stand")
