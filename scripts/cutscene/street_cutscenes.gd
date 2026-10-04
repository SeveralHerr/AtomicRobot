extends Node
class_name StreetCutscenes

## Fires the street's micro cut scenes (CutsceneShots): the opening as the level
## fades in, then each landmark once the player walks up to it with the street quiet.
## Each plays once per session — a restart after a death doesn't replay them.

## Off until the real front end (controls splash) starts a run, so tests, sandbox
## scenes and autoplay scenarios that load main.tscn directly play as before.
static var enabled := false
## Scene ids already played this session.
static var seen := {}

var _current: MicroCutscene
## Seconds the street has been quiet (CutsceneShots.is_quiet) without a break.
var _quiet := 0.0


func _ready() -> void:
	if enabled and not seen.has("opening"):
		_play.call_deferred("opening", true)


func _physics_process(delta: float) -> void:
	if not enabled or _current != null or MicroCutscene.playing:
		return
	var p := _player()
	if p == null or p.is_dead or not p.is_grounded():
		return
	var enemy_xs: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.is_dead:
			enemy_xs.append(e.global_position.x)
	if CutsceneShots.is_quiet(p.global_position.x, enemy_xs, Globals.event_active()):
		_quiet += delta
	else:
		_quiet = 0.0
	for id: String in CutsceneShots.STREET:
		if seen.has(id):
			continue
		var trigger_x: float = CutsceneShots.scene(id)["trigger_x"]
		if CutsceneShots.should_trigger(p.global_position.x, trigger_x, _quiet):
			_play(id, false)
			return


func _play(id: String, instant: bool) -> void:
	var p := _player()
	if p == null:
		return
	seen[id] = true
	_current = MicroCutscene.start(self, id, p, instant)
	_current.finished.connect(func(_skipped: bool) -> void: _current = null)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player
