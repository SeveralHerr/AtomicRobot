extends RefCounted

# Headless sanity tests for the Globals autoload's turn-taking attack-slot manager
# (scripts/autoload/globals.gd). Enemies compete for a capped pool of "attack slots"
# per category (melee/ranged) so a crowd queues up and takes turns instead of all
# attacking the player at once. See docs/LANE_REFACTOR.md and the two call sites:
# Enemy.can_attack (the gate — a pure has_attack_slot_available query, polled every
# frame) and AttackPlayerState.enter_state / exit_state (the claim/release pair).
#
# The manager shipped fully written and fully tested but entirely UNWIRED: crowd
# control was instead done on the lane axis, which routed every enemy but one out of
# the player's lane, so in a wave fight exactly one maid ever swung. Wiring these
# functions up is what makes a crowd take turns, so the contracts below are now load
# bearing rather than aspirational.

var _T
var _globals

const GLOBALS = preload("res://scripts/autoload/globals.gd")

class MockEnemy extends RefCounted:
	var attack_category: String
	func _init(category: String) -> void:
		attack_category = category


func setup() -> void:
	_globals = GLOBALS.new()


func teardown() -> void:
	if _globals:
		_globals.free()
		_globals = null


## Claims `count` slots in `category` and hands back the holders. The caller must keep
## the returned array alive: the pool prunes freed instances, so a dropped MockEnemy
## would quietly give its slot back mid-test.
func _fill_slots(category: String, count: int) -> Array:
	var holders: Array = []
	for i in count:
		var e := MockEnemy.new(category)
		holders.append(e)
		_globals.request_attack_slot(e)
	return holders


## The behavioural tests below derive their expectations from the two constants, so
## re-tuning a cap doesn't rot them. That would also let a cap change slip through
## unnoticed — which is itself the regression (a cap of 1 reads on screen as a 1v1 with
## spectators; 0 would silence the crowd entirely). So pin the shipped values here, in
## one obvious place, and let everything else follow the constants.
func test_slot_caps_are_the_tuned_crowd_values() -> String:
	var r: String = _T.assert_eq(GLOBALS.MAX_MELEE_ATTACKERS, 2, "two melee attackers is the beat-em-up feel")
	if r != "":
		return r
	return _T.assert_eq(GLOBALS.MAX_RANGED_ATTACKERS, 2, "two ranged attackers")


func test_melee_slot_cap_admits_exactly_max_melee_attackers() -> String:
	var holders: Array = []
	for i in GLOBALS.MAX_MELEE_ATTACKERS:
		var e := MockEnemy.new("melee")
		holders.append(e)
		var r: String = _T.assert_true(
			_globals.request_attack_slot(e), "melee claim %d should succeed under the cap" % i)
		if r != "":
			return r
	return _T.assert_false(
		_globals.request_attack_slot(MockEnemy.new("melee")), "melee claim past the cap should fail")


func test_ranged_slot_cap_admits_exactly_max_ranged_attackers() -> String:
	var holders: Array = []
	for i in GLOBALS.MAX_RANGED_ATTACKERS:
		var e := MockEnemy.new("ranged")
		holders.append(e)
		var r: String = _T.assert_true(
			_globals.request_attack_slot(e), "ranged claim %d should succeed under the cap" % i)
		if r != "":
			return r
	return _T.assert_false(
		_globals.request_attack_slot(MockEnemy.new("ranged")), "ranged claim past the cap should fail")


## The two pools are independent: a street brawl must not lock out the window maids
## overhead, and vice versa.
func test_melee_and_ranged_pools_do_not_share_capacity() -> String:
	var _melee := _fill_slots("melee", GLOBALS.MAX_MELEE_ATTACKERS)
	return _T.assert_true(
		_globals.request_attack_slot(MockEnemy.new("ranged")), "a full melee pool must not block a ranged claim")


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
	var holders := _fill_slots("melee", GLOBALS.MAX_MELEE_ATTACKERS)
	var outsider := MockEnemy.new("melee")
	var r: String = _T.assert_false(
		_globals.has_attack_slot_available("melee", outsider), "no slot available for a non-holder while cap is full")
	if r != "":
		return r
	r = _T.assert_true(
		_globals.has_attack_slot_available("melee", holders[0]), "the current holder should still read as available")
	if r != "":
		return r
	# Querying availability must not itself claim a slot.
	return _T.assert_true(_globals.request_attack_slot(holders[0]), "holder can still re-claim after a pure query")


## Enemy.die() releases its slot explicitly, and it has to: _prune_attack_slots only
## drops *freed* instances, and a dying maid stays a perfectly valid object for seconds
## (a 1.5s death timer plus the blink teardown). Nothing about "dead" is visible to the
## pool. Drop the release from die() and a corpse holds a slot until it finally frees,
## stalling the enemy that should have stepped in.
func test_a_dying_holder_keeps_its_slot_until_it_is_released() -> String:
	var holders := _fill_slots("melee", GLOBALS.MAX_MELEE_ATTACKERS)
	var dying = holders[0]
	var next_up := MockEnemy.new("melee")
	var r: String = _T.assert_false(
		_globals.request_attack_slot(next_up), "a still-valid dying holder must not be pruned out from under itself")
	if r != "":
		return r
	_globals.release_attack_slot(dying)
	return _T.assert_true(_globals.request_attack_slot(next_up), "die()'s explicit release must free the slot")


## has_attack_slot_available is a pure query, not a reservation, so two enemies can both
## read it as true in the same frame and both try to enter AttackPlayerState; the loser's
## request_attack_slot returns false and it falls through without swinging. The failure
## path must be inert — a rejected claim that half-registered the loser would leak
## capacity and silence the crowd all over again.
func test_a_lost_claim_race_leaves_the_pool_intact() -> String:
	var holders := _fill_slots("melee", GLOBALS.MAX_MELEE_ATTACKERS)
	var loser := MockEnemy.new("melee")
	var r: String = _T.assert_false(
		_globals.has_attack_slot_available("melee", loser), "a full pool reads as unavailable to a non-holder")
	if r != "":
		return r
	r = _T.assert_false(_globals.request_attack_slot(loser), "the losing claim of a same-frame race must fail")
	if r != "":
		return r
	for i in holders.size():
		r = _T.assert_true(
			_globals.has_attack_slot_available("melee", holders[i]), "winner %d must keep its slot" % i)
		if r != "":
			return r
	# One release frees exactly one slot — no more, no fewer.
	_globals.release_attack_slot(holders[0])
	r = _T.assert_true(_globals.request_attack_slot(loser), "a release after a failed claim still frees a slot")
	if r != "":
		return r
	return _T.assert_false(
		_globals.request_attack_slot(MockEnemy.new("melee")), "one release must not free more than one slot")


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


## Nothing may clear the pool behind the holders' backs.
##
## reset_attack_slots() used to run on player_death. AttackPlayerState tracks its own
## claim in `_slot_held`, so wiping the arrays left an enemy mid-swing believing it
## held a slot the pool had forgotten: two maids sat in AttackPlayerMeleeState while
## the pool reported 0/2, and because the cleared slots were instantly claimable,
## fresh attackers pushed the real count past the cap until the stale swings ended.
## The reset is setup/teardown-only now, and this pins that it stays that way.
func test_ready_does_not_wire_the_pool_reset_to_any_signal() -> String:
	_globals._ready()
	for connection in _globals.player_death.get_connections():
		var target: Callable = connection["callable"]
		if target.get_method() == "reset_attack_slots":
			return "player_death must not be connected to reset_attack_slots"
	return ""


## The consequence the wiring caused, stated as an invariant: a live holder keeps its
## slot until IT gives the slot back. Only release_attack_slot (or being freed) may
## take one away.
func test_a_live_holder_keeps_its_slot_until_it_releases() -> String:
	var holders := _fill_slots("melee", GLOBALS.MAX_MELEE_ATTACKERS)
	var intruder := MockEnemy.new("melee")
	var r: String = _T.assert_false(
		_globals.request_attack_slot(intruder), "pool is full while the holders are alive")
	if r != "":
		return r
	_globals.release_attack_slot(holders[0])
	return _T.assert_true(
		_globals.request_attack_slot(intruder), "a released slot is claimable by the next enemy")
