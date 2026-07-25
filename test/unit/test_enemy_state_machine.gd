extends RefCounted

# Headless tests for EnemyStateMachine's transition rules.
#
# These pin the three guards that stop the "enemy randomly freezes / stops
# attacking" class of bug at the machine level rather than in every state:
#   - death is terminal
#   - an unregistered state name is rejected instead of crashing on states[name]
#   - re-entering the state you are already in is a no-op
#
# The last one matters most: MeterMaidWindow used to poll change_state("Attack...")
# from _physics_process, so the attack animation restarted every frame and could
# never reach its own release frame. Blocking the re-entry is what makes the
# re-arm path in AttackPlayerState the single way to swing again.
#
# EnemyStateMachine._init and EnemyState._init both take a typed `Enemy`, which
# accepts null — so the whole machine can be exercised with recording fakes and
# no scene tree.

var _T
const SM = preload("res://scripts/states/enemy_state_machine.gd")
const DEAD = preload("res://scripts/states/enemy_dead_state.gd")

var _machine


## Records enter/exit so a test can assert transitions actually ran (or didn't).
class RecordingState:
	extends EnemyState
	var enters: int = 0
	var exits: int = 0

	func enter_state() -> void:
		enters += 1

	func exit_state() -> void:
		exits += 1


func setup() -> void:
	_machine = SM.new(null)


func teardown() -> void:
	if _machine:
		_machine.free()
		_machine = null


func _add(name: String) -> RecordingState:
	var s := RecordingState.new(null)
	_machine.add_state(name, s)
	return s


func test_change_state_enters_the_target() -> String:
	var a := _add("A")
	_machine.change_state("A")
	var r: String = _T.assert_eq(a.enters, 1, "target entered once")
	if r != "":
		return r
	return _T.assert_true(_machine.current_state == a, "current_state points at the target")


func test_change_state_exits_the_previous() -> String:
	var a := _add("A")
	var b := _add("B")
	_machine.change_state("A")
	_machine.change_state("B")
	var r: String = _T.assert_eq(a.exits, 1, "previous state exited")
	if r != "":
		return r
	return _T.assert_eq(b.enters, 1, "next state entered")


## The regression that made stationary attackers unable to finish a swing.
func test_re_entering_the_same_state_is_a_no_op() -> String:
	var a := _add("A")
	_machine.change_state("A")
	_machine.change_state("A")
	_machine.change_state("A")
	var r: String = _T.assert_eq(a.enters, 1, "no repeated enter_state")
	if r != "":
		return r
	return _T.assert_eq(a.exits, 0, "no spurious exit_state")


func test_unknown_state_is_rejected_without_changing_state() -> String:
	var a := _add("A")
	_machine.change_state("A")
	# push_error is reported by the runner but must not abort or corrupt state.
	_machine.change_state("NoSuchState")
	var r: String = _T.assert_true(_machine.current_state == a, "stayed in the last valid state")
	if r != "":
		return r
	return _T.assert_eq(a.exits, 0, "rejected transition did not exit the current state")


func test_death_is_terminal() -> String:
	var a := _add("A")
	var dead = DEAD.new(null)
	_machine.add_state("DeadEnemyState", dead)
	_machine.change_state("A")
	# DeadEnemyState.enter_state calls enemy.die(); with a null enemy that would
	# throw, so seat it directly — the guard under test reads current_state only.
	_machine.current_state = dead
	_machine.change_state("A")
	return _T.assert_eq(a.enters, 1, "nothing re-enters after death")


func test_has_state_semantics_match_registration() -> String:
	_add("A")
	var r: String = _T.assert_true(_machine.states.has("A"), "registered name is present")
	if r != "":
		return r
	return _T.assert_false(_machine.states.has("B"), "unregistered name is absent")
