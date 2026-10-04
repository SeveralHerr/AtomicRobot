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
## SceneTree meta holding a faded group's alpha for pieces that join it later.
const _HOLD := "hud_fade_hold_"


## Fade every CanvasItem in `group` to `alpha` over `seconds`, after `delay`. The
## alpha is held until release(): a piece that joins the group meanwhile (the score
## column is injected a frame or more after its level loads) starts at it.
static func fade(tree: SceneTree, group: StringName, alpha: float, seconds: float = 0.3, delay: float = 0.0) -> void:
	_hold(tree, group, alpha)
	for node in tree.get_nodes_in_group(group):
		var tw := _restart(node)
		if tw != null:
			if delay > 0.0:
				tw.tween_interval(delay)
			tw.tween_property(node, "modulate:a", alpha, seconds)


## Forget the held alpha for `group` (a fade back to 1.0 does this too). Call it
## when the scene that faded the HUD goes away mid-fade.
static func release(tree: SceneTree, group: StringName) -> void:
	if tree.has_meta(_HOLD + group):
		tree.remove_meta(_HOLD + group)


static func _hold(tree: SceneTree, group: StringName, alpha: float) -> void:
	if alpha >= 1.0:
		release(tree, group)
		return
	tree.set_meta(_HOLD + group, alpha)
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


static func _on_node_added(node: Node) -> void:
	if not node is CanvasItem:
		return
	var tree := node.get_tree()
	for group in node.get_groups():
		if tree.has_meta(_HOLD + group):
			node.modulate.a = tree.get_meta(_HOLD + group)


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
	# has_meta first: get_meta's null default counts as "no default" and errors.
	if node.has_meta(_META):
		var old: Variant = node.get_meta(_META)
		if old is Tween and old.is_valid():
			old.kill()
	# Runs on a paused tree too: a newspaper pauses the game and clears the HUD.
	var tw := node.create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	node.set_meta(_META, tw)
	return tw
