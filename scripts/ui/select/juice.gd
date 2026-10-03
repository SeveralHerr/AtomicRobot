extends RefCounted

## Tween recipes for the character select. Only ever animate a free child (one no
## Container owns): a Container's re-sort resets its children's scale and rotation.


## Shared look for locked fighters (roster card, stage, info card).
const SILHOUETTE := Color(0.04, 0.06, 0.14)
const LOCK_ICON: Texture2D = preload("res://images/locked.png")


## Click-through full-rect Control: a free layer tweens can move without a Container.
static func layer(parent: Control) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	return c


## Snap to `peak` scale, then spring back to `rest`.
static func pop(node: Control, peak := 1.25, rest := 1.0, time := 0.3) -> Tween:
	node.scale = Vector2.ONE * peak
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE * rest, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Rattle `node` around `rest`, decaying back onto it. `rest` is passed in, never
## read from the node: re-shaking mid-shake would otherwise bake the offset in.
## `axis` (1,0) gives a head-shake "no"; (1,1) a full impact rattle.
static func shake(node: CanvasItem, rest: Vector2, strength := 12.0, time := 0.3,
		axis := Vector2.ONE, steps := 6) -> Tween:
	var t := node.create_tween()
	for i in steps:
		var k := 1.0 - float(i) / steps
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * axis
		if axis.y == 0.0:
			off.x = (1.0 if i % 2 == 0 else -1.0)  # clean left-right "no"
		t.tween_property(node, "position", rest + off * strength * k, time / (steps + 1))
	t.tween_property(node, "position", rest, time / (steps + 1))
	return t


## Comic "stamp": arrives huge and tilted, slams to size.
static func slam(node: Control, angle_deg := -10.0, time := 0.28) -> Tween:
	node.show()
	node.scale = Vector2.ONE * 3.0
	node.rotation_degrees = angle_deg - 18.0
	node.modulate.a = 0.0
	var t := node.create_tween().set_parallel()
	t.tween_property(node, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "rotation_degrees", angle_deg, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, time * 0.4)
	return t
