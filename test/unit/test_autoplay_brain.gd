extends RefCounted

## Autoplay brain decision ladder (tools/autoplay/brain.gd). Each test feeds a
## hand-built snapshot and asserts the intent, so a rule change that breaks an
## earlier playtest fix (door encounter, crate stack) fails here first.

var _T

const Brain := preload("res://tools/autoplay/brain.gd")
const DT := 1.0 / 60.0


static func _p(over: Dictionary = {}) -> Dictionary:
	var p := {"x": 0.0, "y": 0.0, "lane": 1, "hp": 12, "max_hp": 30, "state": "IdleState",
		"grounded": true, "facing": 1, "dead": false, "changing_lane": false, "lanes": true}
	p.merge(over, true)
	return p


static func _snap(p: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var s := {"t": 0.0, "dt": DT, "player": p, "enemies": [], "hearts": [], "pickups": [], "goal_x": 1000.0}
	s.merge(extra, true)
	return s


func test_no_player_and_dead_player_idle() -> String:
	var mem := Brain.new_mem("advance")
	var e: String = _T.assert_eq(Brain.decide({"dt": DT}, mem)["x"], 0, "no player: no input")
	if e != "":
		return e
	var i := Brain.decide(_snap(_p({"dead": true})), mem)
	e = _T.assert_eq(i["x"], 0, "dead: no input")
	if e != "":
		return e
	return _T.assert_true(mem["done"], "death ends the brain step")


func test_advance_walks_toward_goal_and_takes_the_road() -> String:
	var i := Brain.decide(_snap(_p({"lane": 0})), Brain.new_mem("advance"))
	var e: String = _T.assert_eq(i["x"], 1, "walks right toward goal")
	if e != "":
		return e
	return _T.assert_eq(i["lane"], 1, "steps off the walkway onto the road")


func test_advance_without_lanes_stays_put_in_depth() -> String:
	var i := Brain.decide(_snap(_p({"lane": 0, "lanes": false})), Brain.new_mem("advance"))
	return _T.assert_eq(i["lane"], 0, "boss room has no lanes to step into")


func test_attacks_enemy_in_reach_and_facing() -> String:
	var s := _snap(_p(), {"enemies": [{"x": 40.0, "y": 0.0, "lane": 1, "locked": false}]})
	var i := Brain.decide(s, Brain.new_mem("advance"))
	var e: String = _T.assert_true(i["attack"], "attacks")
	if e != "":
		return e
	return _T.assert_eq(i["x"], 0, "stands still to swing")


func test_turns_before_attacking_an_enemy_behind() -> String:
	var s := _snap(_p({"facing": 1}), {"enemies": [{"x": -40.0, "y": 0.0, "lane": 1, "locked": false}]})
	var i := Brain.decide(s, Brain.new_mem("advance"))
	var e: String = _T.assert_eq(i["x"], -1, "turns left first")
	if e != "":
		return e
	return _T.assert_false(i["attack"], "no swing into empty air")


func test_matches_enemy_lane() -> String:
	var s := _snap(_p({"lane": 1}), {"enemies": [{"x": 40.0, "y": 48.0, "lane": 3, "locked": false}]})
	var i := Brain.decide(s, Brain.new_mem("advance"))
	var e: String = _T.assert_eq(i["lane"], 1, "steps toward lane 3")
	if e != "":
		return e
	return _T.assert_false(i["attack"], "no swing across lanes: combat only connects in-lane")


func test_ignores_lane_locked_enemy_in_reach() -> String:
	var s := _snap(_p(), {"enemies": [{"x": 40.0, "y": 0.0, "lane": 1, "locked": true}]})
	var i := Brain.decide(s, Brain.new_mem("advance"))
	return _T.assert_false(i["why"].begins_with("fight"), "lane-locked (window/platform) maid is never a target")


func test_ignores_enemy_far_above() -> String:
	var s := _snap(_p(), {"enemies": [{"x": 40.0, "y": -300.0, "lane": 1, "locked": false}]})
	var i := Brain.decide(s, Brain.new_mem("advance"))
	return _T.assert_false(i["why"].begins_with("fight"), "rooftop maid is out of reach")


func test_ignores_enemy_beyond_engage_range() -> String:
	var s := _snap(_p(), {"enemies": [{"x": Brain.ENGAGE_RANGE + 10.0, "y": 0.0, "lane": 1, "locked": false}]})
	var i := Brain.decide(s, Brain.new_mem("advance"))
	return _T.assert_eq(i["why"], "advance", "keeps advancing past a far enemy")


func test_too_close_backs_off() -> String:
	var s := _snap(_p(), {"enemies": [{"x": 5.0, "y": 0.0, "lane": 1, "locked": false}]})
	var i := Brain.decide(s, Brain.new_mem("advance"))
	return _T.assert_eq(i["x"], -1, "steps away to get the enemy into the hitbox")


func test_heal_threshold_is_inclusive() -> String:
	var hearts := {"hearts": [{"x": -300.0, "y": 0.0}]}
	var at := Brain.decide(_snap(_p({"hp": Brain.HEAL_HP}), hearts), Brain.new_mem("advance"))
	var above := Brain.decide(_snap(_p({"hp": Brain.HEAL_HP + 1}), hearts), Brain.new_mem("advance"))
	var e: String = _T.assert_eq(at["why"], "heal", "heals at HEAL_HP")
	if e != "":
		return e
	return _T.assert_eq(above["why"], "advance", "does not detour at HEAL_HP + 1")


func test_no_lane_step_while_changing_lane() -> String:
	var s := _snap(_p({"lane": 1, "changing_lane": true}),
		{"enemies": [{"x": 40.0, "y": 48.0, "lane": 3, "locked": false}]})
	return _T.assert_eq(Brain.decide(s, Brain.new_mem("advance"))["lane"], 0, "waits for the tween")


func test_close_threat_beats_heading_for_a_heart() -> String:
	# The door-encounter death: low hp, a heart beyond the barrier, maids adjacent.
	var s := _snap(_p({"hp": 3}), {"enemies": [{"x": 40.0, "y": 0.0, "lane": 1, "locked": false}],
		"hearts": [{"x": 300.0, "y": 0.0}]})
	var i := Brain.decide(s, Brain.new_mem("advance"))
	return _T.assert_true(i["attack"], "fights the adjacent maid instead of walking to the heart")


func test_low_hp_heads_for_heart() -> String:
	var s := _snap(_p({"hp": 3}), {"hearts": [{"x": -300.0, "y": 0.0}]})
	var i := Brain.decide(s, Brain.new_mem("advance"))
	var e: String = _T.assert_eq(i["x"], -1, "walks back to the heart")
	if e != "":
		return e
	return _T.assert_eq(i["lane"], 0, "does not switch lanes while the heart is far")


func test_heart_straight_below_a_ledge_walks_off() -> String:
	var s := _snap(_p({"hp": 3, "y": -250.0, "facing": -1}), {"hearts": [{"x": 2.0, "y": -40.0}]})
	var i := Brain.decide(s, Brain.new_mem("advance"))
	return _T.assert_eq(i["x"], -1, "walks off the ledge in its facing direction")


func test_stuck_escalates_jump_then_marks_road_block() -> String:
	var mem := Brain.new_mem("advance")
	var s := _snap(_p({"x": 500.0, "state": "RunState"}))
	var jumped := false
	var blocked := false
	# (lane 1 = on the road, lanes active: the escape is a step to the walkway)
	for f in int(Brain.STUCK_LANE_S / DT) + 2:
		var i := Brain.decide(s, mem)
		jumped = jumped or i["jump"]
		blocked = blocked or i["lane"] == -1
	var e: String = _T.assert_true(jumped, "jumps when pinned")
	if e != "":
		return e
	e = _T.assert_true(blocked, "steps toward the walkway when the road is blocked")
	if e != "":
		return e
	return _T.assert_eq(mem["road_blocked"].size(), 1, "remembers the block")


func test_never_jumps_over_a_pending_lane_step() -> String:
	var mem := Brain.new_mem("advance")
	var s := _snap(_p({"x": 500.0, "state": "RunState"}))
	for f in int(Brain.STUCK_LANE_S / DT) + 2:
		var i := Brain.decide(s, mem)
		if i["lane"] != 0 and i["jump"]:
			return "jumped on a lane-step frame: try_change_lane refuses airborne players"
	return ""


func test_enemies_beyond_a_road_block_are_not_targets() -> String:
	var mem := Brain.new_mem("advance")
	mem["road_blocked"] = [520.0]
	var s := _snap(_p({"x": 500.0}), {"enemies": [{"x": 560.0, "y": 0.0, "lane": 1, "locked": false}]})
	var i := Brain.decide(s, mem)
	return _T.assert_false(i["why"].begins_with("fight"), "maid behind the crate stack is ignored")


func test_player_pinned_at_a_block_still_sees_enemies_on_its_side() -> String:
	var mem := Brain.new_mem("advance")
	mem["road_blocked"] = [500.0]
	var s := _snap(_p({"x": 500.0}), {"enemies": [{"x": 460.0, "y": 0.0, "lane": 1, "locked": false}]})
	return _T.assert_true(Brain.decide(s, mem)["why"].begins_with("fight"), "same-side maid is still fought")


func test_scene_change_forgets_road_blocks() -> String:
	var mem := Brain.new_mem("advance")
	Brain.decide(_snap(_p(), {"scene_id": 1}), mem)
	mem["road_blocked"] = [520.0]
	Brain.decide(_snap(_p(), {"scene_id": 2}), mem)
	return _T.assert_true(mem["road_blocked"].is_empty(), "street blocks don't leak into the boss room")


func test_lane_escape_is_held_until_the_lane_changes() -> String:
	# Player.try_change_lane refuses airborne players: a one-frame request is lost.
	var mem := Brain.new_mem("advance")
	var s := _snap(_p({"x": 500.0, "lane": 1, "state": "RunState"}))
	var frames_asking := 0
	for f in int((Brain.STUCK_LANE_S + 0.5) / DT):
		var i := Brain.decide(s, mem)
		if i["lane"] == -1:
			frames_asking += 1
			if i["jump"]:
				return "jumped while asking for the lane step"
	return _T.assert_gt(frames_asking, 10, "keeps asking for several frames")


func test_near_road_block_travels_on_walkway() -> String:
	var mem := Brain.new_mem("advance")
	mem["road_blocked"] = [520.0]
	var i := Brain.decide(_snap(_p({"x": 480.0, "lane": 1})), mem)
	return _T.assert_eq(i["lane"], -1, "heads for the walkway near the block")


func test_clear_goal_finishes_after_quiet_period() -> String:
	var mem := Brain.new_mem("clear")
	for f in int(Brain.CLEAR_QUIET_S / DT) + 2:
		Brain.decide(_snap(_p()), mem)
	var e: String = _T.assert_true(mem["done"], "clear ends once nothing is in range")
	if e != "":
		return e
	Brain.decide(_snap(_p(), {"enemies": [{"x": 100.0, "y": 0.0, "lane": 1, "locked": false}]}), mem)
	e = _T.assert_false(mem["done"], "a new enemy re-opens the fight")
	if e != "":
		return e
	return _T.assert_eq(mem["quiet_s"], 0.0, "quiet timer resets")


func test_stuck_long_enough_backs_off_then_running_jumps() -> String:
	var mem := Brain.new_mem("advance")
	var s := _snap(_p({"x": 500.0, "lane": 0, "lanes": false, "state": "RunState"}))
	var backed := false
	var running_jump := false
	for f in int((Brain.STUCK_BACK_S + Brain.BACKOFF_MAX_S + 0.2) / DT):
		var i := Brain.decide(s, mem)
		backed = backed or (i["why"] == "unstick: back off" and i["x"] == -1)
		running_jump = running_jump or (i["why"] == "unstick: running jump" and i["jump"] and i["x"] == 1)
	var e: String = _T.assert_true(backed, "backs away from the wall")
	if e != "":
		return e
	return _T.assert_true(running_jump, "then jumps while moving forward")


func test_backoff_length_is_seeded() -> String:
	var lengths := []
	for run in 2:
		var mem := Brain.new_mem("advance", 42)
		var s := _snap(_p({"x": 500.0, "lane": 0, "lanes": false, "state": "RunState"}))
		for f in int((Brain.STUCK_BACK_S + 1.0) / DT):
			if mem["backoff_s"] > 0.0:
				break
			Brain.decide(s, mem)
		lengths.append(mem["backoff_s"])
	return _T.assert_eq(lengths[0], lengths[1], "same seed, same back-off")


func test_monkey_is_reproducible_per_seed() -> String:
	var a := Brain.new_mem("monkey", 7)
	var b := Brain.new_mem("monkey", 7)
	for f in 120:
		var ia := Brain.decide(_snap(_p()), a)
		var ib := Brain.decide(_snap(_p()), b)
		if ia != ib:
			return "same seed diverged at frame %d" % f
	return ""


func test_idle_watchdog_wanders() -> String:
	# An item straight above a player who cannot reach it used to idle forever.
	var mem := Brain.new_mem("advance")
	var s := _snap(_p({"hp": 3, "facing": 1}), {"hearts": [{"x": 2.0, "y": 0.0}]})
	var moved := false
	for f in int((Brain.IDLE_MAX_S + 0.1) / DT):
		moved = moved or Brain.decide(s, mem)["x"] != 0
	return _T.assert_true(moved, "idle watchdog makes the bot move")
