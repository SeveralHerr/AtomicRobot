extends RefCounted

# HudFade (scripts/ui/hud_fade.gd): group-wide HUD fades for cinematics and callouts.

var _T

const GROUP := &"test_hud_fade"

var _node: Control


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _real(seconds: float) -> void:
	await _tree().create_timer(seconds, true, false, true).timeout


func setup() -> void:
	_node = Control.new()
	_node.add_to_group(GROUP)
	_tree().root.add_child(_node)
	await _tree().process_frame  # soak up a post-load hitch frame


func teardown() -> void:
	_node.free()


func test_hud_fade_reaches_its_alpha() -> String:
	HudFade.fade(_tree(), GROUP, 0.0, 0.05)
	await _real(0.2)
	return _T.assert_float_eq(_node.modulate.a, 0.0, 0.01, "faded out")


## The newest fade wins: a cinematic fade-out started while a callout's duck is
## running must not be undone when the old duck's tail fades the HUD back in.
func test_hud_fade_newest_call_wins() -> String:
	HudFade.duck(_tree(), GROUP, 0.1, 0.05, 0.05)
	HudFade.fade(_tree(), GROUP, 0.0, 0.05)
	await _real(0.4)
	return _T.assert_float_eq(_node.modulate.a, 0.0, 0.01, "stays out after the old duck would have ended")


func test_hud_fade_skips_non_canvas_nodes() -> String:
	var plain := Node.new()
	plain.add_to_group(GROUP)
	_tree().root.add_child(plain)
	HudFade.fade(_tree(), GROUP, 0.0, 0.05)
	var tagged: bool = plain.has_meta(&"hud_fade_tween")
	plain.free()
	return _T.assert_false(tagged, "a plain Node in the group is left alone")
