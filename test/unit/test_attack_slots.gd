extends RefCounted

# Headless sanity tests for the Globals autoload's turn-taking attack-slot manager
# (scripts/autoload/globals.gd). Enemies compete for a capped pool of "attack slots"
# per category (melee/ranged) so a crowd queues up and takes turns instead of all
# attacking the player at once. See docs/LANE_REFACTOR.md and scripts/enemy.gd
# (can_attack / _chase_toward_player).

var _T
var _globals

class MockEnemy extends RefCounted:
	var attack_category: String
	func _init(category: String) -> void:
		attack_category = category


func setup() -> void:
	_globals = load("res://scripts/autoload/globals.gd").new()


func teardown() -> void:
	if _globals:
		_globals.free()
		_globals = null


func test_melee_slot_cap_is_one() -> String:
	var a := MockEnemy.new("melee")
	var b := MockEnemy.new("melee")
	var r: String = _T.assert_true(_globals.request_attack_slot(a), "first melee claim should succeed")
	if r != "":
		return r
	return _T.assert_false(_globals.request_attack_slot(b), "second melee claim should fail while cap=1 is held")


func test_ranged_slot_cap_is_two() -> String:
	var a := MockEnemy.new("ranged")
	var b := MockEnemy.new("ranged")
	var c := MockEnemy.new("ranged")
	_globals.request_attack_slot(a)
	_globals.request_attack_slot(b)
	return _T.assert_false(_globals.request_attack_slot(c), "third ranged claim should fail while cap=2 is held")


func test_request_is_idempotent_for_holder() -> String:
	var a := MockEnemy.new("melee")
	_globals.request_attack_slot(a)
	return _T.assert_true(_globals.request_attack_slot(a), "re-claiming an already-held slot should succeed")


func test_release_frees_slot_for_next_claimant() -> String:
	var a := MockEnemy.new("melee")
	var b := MockEnemy.new("melee")
	_globals.request_attack_slot(a)
	_globals.release_attack_slot(a)
	return _T.assert_true(_globals.request_attack_slot(b), "slot should be free after release")


func test_has_attack_slot_available_is_pure() -> String:
	var a := MockEnemy.new("melee")
	var b := MockEnemy.new("melee")
	_globals.request_attack_slot(a)
	var r: String = _T.assert_false(
		_globals.has_attack_slot_available("melee", b), "no slot available for a non-holder while cap is full")
	if r != "":
		return r
	r = _T.assert_true(
		_globals.has_attack_slot_available("melee", a), "the current holder should still read as available")
	if r != "":
		return r
	# Querying availability must not itself claim a slot.
	return _T.assert_true(_globals.request_attack_slot(a), "holder can still re-claim after a pure query")


func test_reset_clears_all_categories() -> String:
	var a := MockEnemy.new("melee")
	var b := MockEnemy.new("ranged")
	_globals.request_attack_slot(a)
	_globals.request_attack_slot(b)
	_globals.reset_attack_slots()
	var r: String = _T.assert_true(_globals.request_attack_slot(MockEnemy.new("melee")), "melee slot free after reset")
	if r != "":
		return r
	return _T.assert_true(_globals.request_attack_slot(MockEnemy.new("ranged")), "ranged slot free after reset")
