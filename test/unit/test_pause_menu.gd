extends RefCounted

# The pause menu's place in the canvas-layer stack.
#
# The CRT overlay's shader reads hint_screen_texture, so it only treats what is already
# composited below it. The pause menu shipped on layer 101 against the overlay's 100,
# which drew it ABOVE the effect: the game behind it was warped and scanlined while the
# menu itself sat there crisp and flat, looking like it belonged to a different game.
# Nothing else in the project can catch that - it is a draw-order fact, invisible to
# lint and to any test that only instantiates the menu on its own.

var _T

const PAUSE_MENU := "res://scenes/pause_menu.tscn"
const CRT := preload("res://scripts/autoload/crt_overlay.gd")


func _pause_menu_layer() -> int:
	var scene: PackedScene = load(PAUSE_MENU)
	var node := scene.instantiate()
	var layer: int = node.layer
	node.free()
	return layer


func test_pause_menu_draws_under_the_crt_overlay() -> String:
	var layer := _pause_menu_layer()
	if layer >= CRT.OVERLAY_LAYER:
		return "pause menu is on layer %d, at or above the CRT overlay's %d - it would render unfiltered over the effect" % [
			layer, CRT.OVERLAY_LAYER]
	return ""


## ...but still above the game and its HUD, or pausing would hide the menu behind the
## level. Authored scene layers top out at 2 (see crt_overlay.gd).
func test_pause_menu_draws_over_the_game() -> String:
	return _T.assert_gt(float(_pause_menu_layer()), 2.0,
		"pause menu must outrank every authored scene layer")
