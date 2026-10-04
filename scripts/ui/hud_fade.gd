extends RefCounted
class_name HudFade

## Fades HUD pieces by node group, so a cinematic or a callout can clear the HUD
## without holding references into it: the score column is injected per level by
## ScoreSystem and the HP orbs belong to each level's own UI layer. Tweens
## `modulate:a` on real time — callouts often land inside a hitstop.

## Faded out under the boss-intro letterbox: HP orbs, portrait, score column.
const CINEMATIC := &"hud_cinematic"
## Ducked while the STREET CLEAR! burst is up: it would sit right over them.
const POWERUPS := &"hud_powerups"
const _META := &"hud_fade_tween"


## Fade every CanvasItem in `group` to `alpha` over `seconds`.
static func fade(tree: SceneTree, group: StringName, alpha: float, seconds: float = 0.3) -> void:
	for node in tree.get_nodes_in_group(group):
		var tw := _restart(node)
		if tw != null:
			tw.tween_property(node, "modulate:a", alpha, seconds)


## Fade `group` out, hold `hold` seconds, fade it back. Each tween lives on its HUD
## node, so the HUD comes back even if the caller (an encounter) is freed meanwhile.
static func duck(tree: SceneTree, group: StringName, hold: float, out_s: float = 0.1, in_s: float = 0.25) -> void:
	for node in tree.get_nodes_in_group(group):
		var tw := _restart(node)
		if tw != null:
			tw.tween_property(node, "modulate:a", 0.0, out_s)
			tw.tween_interval(hold)
			tw.tween_property(node, "modulate:a", 1.0, in_s)


## One fade per node: a new one kills the last, so a duck landing mid-fade can't
## leave two tweens fighting over the alpha.
static func _restart(node: Node) -> Tween:
	if not node is CanvasItem:
		return null
	var old: Variant = node.get_meta(_META, null)
	if old is Tween and old.is_valid():
		old.kill()
	var tw := node.create_tween().set_ignore_time_scale(true)
	node.set_meta(_META, tw)
	return tw
