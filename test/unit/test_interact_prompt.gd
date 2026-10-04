extends RefCounted

# Every "[interact]" prompt (newspaper stand, secret wall orb) is one look: the same
# shared LabelSettings and text, and no per-prop restyle in code or in a level's
# instance overrides. Scenes are derived from the .tscn files, not listed by hand.

var _T

const STYLE := "res://styles/interact_prompt.tres"
const TEXT := "[interact]"
## Props the player knows as secrets: the derived set must include them.
const KNOWN := ["res://scenes/crack.tscn", "res://scenes/interactive_mailbox.tscn"]

var _nodes: Array[Node] = []


func teardown() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## [path, text] of every .tscn under res://scenes that mentions an InteractLabel.
static func _scenes_with_prompts() -> Array:
	var out := []
	for f in DirAccess.get_files_at("res://scenes"):
		if not f.ends_with(".tscn"):
			continue
		var path := "res://scenes/" + f
		var text := FileAccess.get_file_as_string(path)
		if text.contains("[node name=\"InteractLabel\""):
			out.append([path, text])
	return out


## The InteractLabel node block (header to the next node header) in a .tscn text.
static func _label_blocks(text: String) -> Array[String]:
	var blocks: Array[String] = []
	var at := text.find("[node name=\"InteractLabel\"")
	while at >= 0:
		var end := text.find("\n[", at + 1)
		blocks.append(text.substr(at, (end if end >= 0 else text.length()) - at))
		at = text.find("[node name=\"InteractLabel\"", at + 1)
	return blocks


func test_known_prompt_props_are_found() -> String:
	var found := _scenes_with_prompts().map(func(p: Array) -> String: return p[0])
	for k in KNOWN:
		var r: String = _T.assert_true(k in found, "%s has an InteractLabel" % k)
		if r != "":
			return r
	return ""


## Definitions use the shared style + text; level overrides restyle nothing.
func test_every_prompt_shares_one_style_and_text() -> String:
	for p in _scenes_with_prompts():
		for block in _label_blocks(p[1]):
			var defines := block.contains("type=\"Label\"")
			var r: String
			if defines:
				r = _T.assert_true(block.contains("text = \"%s\"" % TEXT), "%s: text %s" % [p[0], TEXT])
				if r != "":
					return r
				r = _T.assert_true(p[1].contains("path=\"%s\"" % STYLE) and not block.contains("SubResource"),
					"%s: label_settings is the shared %s" % [p[0], STYLE])
			else:
				r = _T.assert_false(block.contains("text =") or block.contains("label_settings ="),
					"%s: an instance override restyles the prompt" % p[0])
			if r != "":
				return r
	return ""


## Runtime too: no script restyles, retexts or bobs its prompt.
func test_live_prompts_keep_the_shared_look() -> String:
	for path in KNOWN:
		var n: Node = (load(path) as PackedScene).instantiate()
		_tree().root.add_child(n)
		_nodes.append(n)
		await _tree().process_frame
		if n.has_method("_offer_claim"):
			n._offer_claim()
		var label: Label = n.get_node("InteractLabel")
		var y := label.position.y
		await _tree().create_timer(0.25).timeout
		var r: String = _T.assert_eq(label.label_settings.resource_path, STYLE, "%s live style" % path)
		if r != "":
			return r
		r = _T.assert_eq(label.text, TEXT, "%s live text" % path)
		if r != "":
			return r
		r = _T.assert_eq(label.position.y, y, "%s prompt holds still (stand's doesn't bob)" % path)
		if r != "":
			return r
	return ""
