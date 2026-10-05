extends RefCounted

# State objects (State / EnemyState) are Nodes the state machines keep only in a
# dictionary, never in the tree. Freeing their owner used to leave every one of
# them behind as an orphan: ~150 extra orphan nodes per playthrough on a 1 GB Pi
# that runs the game all day. Each test spawns real scenes, frees them the way
# the game does, and checks the orphan count is back where it started.

var _T

const ENEMY_SCENES := [
	"res://scenes/meter_maid.tscn",
	"res://scenes/meter_maid_melee.tscn",
	"res://scenes/meter_maid_platform.tscn",
	"res://scenes/meter_maid_window.tscn",
	"res://scenes/final_boss.tscn",
]
const PLAYER_SCENE := "res://scenes/player.tscn"
const ROUNDS := 3

var _kills_before: int
var _root_before: Array[Node] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func setup() -> void:
	_kills_before = Globals.meter_maids_killed
	_root_before.assign(_tree().root.get_children())


func teardown() -> void:
	# die() can drop a pickup into the tree; don't leak it into later tests.
	for n in _tree().root.get_children():
		if not _root_before.has(n):
			n.queue_free()
	await _tree().process_frame
	Globals.meter_maids_killed = _kills_before


func _spawn(path: String) -> Node:
	var n: Node = load(path).instantiate()
	_tree().root.add_child(n)
	n.set_process(false)
	n.set_physics_process(false)
	return n


func _settle() -> void:
	for i in 3:
		await _tree().process_frame


func test_freed_enemies_leave_no_orphan_states() -> String:
	await _settle()
	var base := _orphans()
	for i in ROUNDS:
		for path in ENEMY_SCENES:
			var e: Enemy = _spawn(path)
			await _tree().process_frame
			Globals.release_attack_slot(e)
			e.free()
	await _settle()
	return _T.assert_eq(_orphans(), base, "orphan nodes after freeing %d enemies" % (ROUNDS * ENEMY_SCENES.size()))


func test_enemies_killed_via_die_leave_no_orphan_states() -> String:
	await _settle()
	var base := _orphans()
	var left: Array[Node] = []
	for i in ROUNDS:
		for path in ENEMY_SCENES:
			var e: Enemy = _spawn(path)
			await _tree().process_frame
			# The real kill path: DeadEnemyState -> die(), which awaits its death
			# fade. Free mid-await (as the blink-out's queue_free does) so a pending
			# coroutine on a freed state/enemy must not raise errors either.
			e.health = 0
			e.enemy_state_machine.change_state("DeadEnemyState")
			await _tree().process_frame
			e._on_death_blink_finished()
			left.append(e)
	await _settle()
	# The window maid's corpse and the boss stay in the level by design until the
	# scene changes; the scene change is what frees them.
	for e in left:
		if is_instance_valid(e):
			e.free()
	await _settle()
	return _T.assert_eq(_orphans(), base, "orphan nodes after killing %d enemies" % (ROUNDS * ENEMY_SCENES.size()))


func test_freed_players_leave_no_orphan_states() -> String:
	await _settle()
	var base := _orphans()
	for i in ROUNDS:
		var p: Player = _spawn(PLAYER_SCENE)
		await _tree().process_frame
		p.queue_free()
		await _tree().process_frame
	await _settle()
	return _T.assert_eq(_orphans(), base, "orphan nodes after freeing %d players" % ROUNDS)


## Lanes.join_sort_layer reparents every enemy into the Y-sort layer, so leaving
## the tree is not dying: the states must survive it (freed only on PREDELETE).
func test_reparented_enemy_keeps_its_states() -> String:
	var e: Enemy = _spawn(ENEMY_SCENES[0])
	var holder := Node2D.new()
	_tree().root.add_child(holder)
	e.reparent(holder)
	var alive := 0
	for s in e.enemy_state_machine.states.values():
		alive += 1 if is_instance_valid(s) else 0
	var total: int = e.enemy_state_machine.states.size()
	Globals.release_attack_slot(e)
	holder.free()
	if total == 0:
		return "maid registered no states"
	return _T.assert_eq(alive, total, "states still valid after a reparent")
