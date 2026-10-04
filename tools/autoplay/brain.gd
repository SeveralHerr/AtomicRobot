extends RefCounted

## Autoplay decision maker. Pure: decide(snapshot, mem) -> intent, no scene tree,
## so every rule is unit tested (test/unit/test_autoplay_brain.gd).
##
## Snapshot fields read here (world.gd builds more, for dumps):
##   {dt, goal_x, player: {x, y, lane, hp, state, facing, dead, changing_lane, lanes}
##    or {}, enemies: [{x, y, lane, locked}], hearts: [{x, y}], pickups: [{x, y, lane}]}
## Intent (consumed by pad.gd):
##   {x: -1|0|1, run, jump, attack, crouch: bool, lane: -1|0|1, why: String}
##
## Priority ladder, first match wins: dead -> close threat -> heal -> pickup ->
## fight -> advance, then unstick adjusts whatever won. `mem` is the brain's own
## scratch state; the caller keeps it between frames and reads only mem.done.

## Horizontal distance at which an enemy becomes the target.
const ENGAGE_RANGE := 260.0
## Attack window in front of the player: hitbox circle r=32 at local x=48.
const REACH_MIN := 14.0
const REACH_MAX := 70.0
## Enemies further than this above/below are out of reach (platform/window maids).
const MAX_DY := 60.0
## Go for hearts at or below this many hit points (two HUD orbs).
const HEAL_HP := 6
## An enemy this close is fought before anything else, hearts included: walking
## away from a crowd toward a heart is how the bot died at the door encounter.
const CLOSE_THREAT := 140.0
const HEART_RANGE := 900.0
## Chasing one heart this long means it is out of reach (up on the crate stack):
## skip it for the rest of the scene instead of soft-locking the run on it.
const HEAL_GIVE_UP_S := 15.0
const PICKUP_RANGE := 320.0
## Seconds of no progress before each unstick move.
const STUCK_JUMP_S := 0.6
const STUCK_LANE_S := 1.8
const STUCK_BACK_S := 3.2
## Quiet gap before the lane rung (lets a jump land) and how long a lane escape
## request is held before giving up.
const LAND_BEFORE_LANE_S := 0.5
const LANE_REQ_S := 1.0
const BACKOFF_MIN_S := 0.1
const BACKOFF_MAX_S := 0.8
## Only step into an item's lane once this close: lanes are how you get AROUND
## walkway obstacles (crate stacks), so switching early walks into them.
const LANE_COMMIT_DX := 150.0
## Around a spot where the road was blocked, travel on the walkway instead: raised
## steps (bins, crate tops) only exist on the ground lane.
const ROAD_BLOCK_SPAN := 250.0
## Progress smaller than this does not reset the stuck timer.
const PROGRESS_PX := 6.0
const ARRIVE_PX := 24.0
## "clear" is done after this long with nothing in range.
const CLEAR_QUIET_S := 1.5
## Standing still this long without attacking is a bug in the ladder (an item
## straight below a ledge, a target that can never be reached): wander for
## WANDER_S so the run keeps producing information instead of idling to timeout.
const IDLE_MAX_S := 4.0
const WANDER_S := 1.0
const LEGIT_IDLE := ["at goal", "nothing to do"]


static func new_mem(goal: String, seed_value: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return {
		"goal": goal, "rng": rng, "anchor_x": INF, "stuck_s": 0.0,
		"lane_tried": false, "backoff_s": 0.0, "quiet_s": 0.0, "done": false,
		"monkey_left": 0.0, "monkey": idle(""), "idle_s": 0.0, "backoff_dir": 1, "jump_next": false,
		"road_blocked": [], "skip_hearts": [], "heal_x": INF, "heal_s": 0.0, "scene_id": 0, "lane_req": 0, "lane_req_s": 0.0, "lane_req_from": 0,
	}


## Positions are per scene: a street block x means nothing in the boss room.
const _SCENE_STATE := {"anchor_x": INF, "stuck_s": 0.0, "lane_tried": false, "backoff_s": 0.0,
	"jump_next": false, "idle_s": 0.0, "lane_req": 0, "lane_req_s": 0.0, "heal_x": INF, "heal_s": 0.0}


static func _enter_scene(snap: Dictionary, mem: Dictionary) -> void:
	var id: int = snap.get("scene_id", 0)
	if id == mem["scene_id"]:
		return
	mem["scene_id"] = id
	mem.merge(_SCENE_STATE, true)
	mem["road_blocked"] = []
	mem["skip_hearts"] = []


static func idle(why: String) -> Dictionary:
	return {"x": 0, "run": false, "jump": false, "attack": false, "crouch": false, "lane": 0, "why": why}


static func decide(snap: Dictionary, mem: Dictionary) -> Dictionary:
	var p: Dictionary = snap.get("player", {})
	if p.is_empty():
		return idle("no player")
	if p.get("dead", false):
		mem["done"] = true
		return idle("dead")
	var dt: float = snap.get("dt", 0.0)
	_enter_scene(snap, mem)
	if mem["goal"] == "monkey":
		return _monkey(dt, mem)

	var target := nearest_enemy(p, snap.get("enemies", []), mem["road_blocked"])
	if mem["goal"] == "clear":
		mem["quiet_s"] = 0.0 if not target.is_empty() else mem["quiet_s"] + dt
		mem["done"] = mem["quiet_s"] >= CLEAR_QUIET_S

	var intent := {}
	if not target.is_empty() and absf(target["x"] - p["x"]) <= CLOSE_THREAT:
		intent = _fight(p, target)
	if intent.is_empty():
		intent = _heal(p, snap, mem)
	if intent.is_empty():
		intent = _pickup(p, snap)
	if intent.is_empty() and not target.is_empty():
		intent = _fight(p, target)
	if intent.is_empty() and mem["goal"] == "advance":
		intent = _advance(p, snap.get("goal_x", INF), mem["road_blocked"])
	if intent.is_empty():
		intent = idle("nothing to do")
	return _unstick(p, intent, dt, mem)


## Nearest live, reachable enemy within ENGAGE_RANGE, any lane. {} if none.
## Enemies on the far side of a known road block are unreachable: chasing them is
## what pinned the bot against the crate stack.
static func nearest_enemy(p: Dictionary, enemies: Array, blocked: Array = []) -> Dictionary:
	var best := {}
	var best_d := INF
	for e: Dictionary in enemies:
		if e.get("locked", false) or absf(e["y"] - p["y"]) > MAX_DY + _lane_dy(p, e):
			continue
		# Strictly opposite sides: a player pinned exactly AT the block still sees
		# enemies on its own side.
		if blocked.any(func(bx: float) -> bool: return (e["x"] - bx) * (p["x"] - bx) < 0.0):
			continue
		var d := absf(e["x"] - p["x"])
		if d <= ENGAGE_RANGE and d < best_d:
			best = e
			best_d = d
	return best


## Lanes sit LANE_SPACING apart in Y, so lane distance is not height distance.
static func _lane_dy(p: Dictionary, e: Dictionary) -> float:
	return absf(float(e.get("lane", 0) - p.get("lane", 0))) * Lanes.LANE_SPACING


static func _heal(p: Dictionary, snap: Dictionary, mem: Dictionary) -> Dictionary:
	if int(p["hp"]) > HEAL_HP:
		return {}
	var skip: Array = mem["skip_hearts"]
	var hearts: Array = snap.get("hearts", []).filter(func(h: Dictionary) -> bool: return not skip.has(h["x"]))
	var heart := _nearest_x(p, hearts, HEART_RANGE)
	if heart.is_empty():
		return {}
	if heart["x"] != mem["heal_x"]:
		mem["heal_x"] = heart["x"]
		mem["heal_s"] = 0.0
	mem["heal_s"] += float(snap.get("dt", 0.0))
	if mem["heal_s"] >= HEAL_GIVE_UP_S:
		skip.append(heart["x"])
		return {}
	# Hearts sit on the walkway: collect from the ground lane.
	return _go_to(p, heart, Lanes.GROUND_LANE, "heal")


static func _pickup(p: Dictionary, snap: Dictionary) -> Dictionary:
	var pk := _nearest_x(p, snap.get("pickups", []), PICKUP_RANGE)
	if pk.is_empty():
		return {}
	return _go_to(p, pk, int(pk.get("lane", p["lane"])), "pickup")


static func _go_to(p: Dictionary, item: Dictionary, lane: int, why: String) -> Dictionary:
	var i := idle(why)
	var dx: float = item["x"] - p["x"]
	if lane != p["lane"] and absf(dx) < LANE_COMMIT_DX:
		i["lane"] = _lane_step(p, lane)
	if absf(dx) > 4.0:
		i["x"] = _side(dx)
	# Above us and close: jump for it. Below us (we're on a ledge): walk off.
	if item["y"] < p["y"] - 30.0 and absf(dx) < 40.0:
		i["jump"] = true
	elif i["x"] == 0 and item["y"] > p["y"] + 40.0:
		i["x"] = int(p.get("facing", 1))
		i["why"] = why + ": drop down"
	return i


static func _fight(p: Dictionary, e: Dictionary) -> Dictionary:
	var i := idle("fight")
	var dx: float = e["x"] - p["x"]
	var side := _side(dx) if dx != 0.0 else int(p.get("facing", 1))
	if e.get("lane", 0) != p["lane"]:
		i["lane"] = _lane_step(p, e["lane"])
		i["why"] = "fight: match lane %d" % e["lane"]
	var ad := absf(dx)
	if ad > REACH_MAX:
		i["x"] = side
		i["why"] = "fight: close in"
	elif ad < REACH_MIN:
		i["x"] = -side
		i["why"] = "fight: too close, back off"
	elif int(p.get("facing", 1)) != side:
		i["x"] = side
		i["why"] = "fight: turn"
	elif e.get("lane", 0) == p["lane"]:
		i["attack"] = true
		i["why"] = "fight: attack"
	return i


static func _advance(p: Dictionary, goal_x: float, road_blocked: Array = []) -> Dictionary:
	if is_finite(goal_x) and absf(goal_x - p["x"]) <= ARRIVE_PX:
		return idle("at goal")
	var i := idle("advance")
	i["x"] = 1 if not is_finite(goal_x) else _side(goal_x - p["x"])
	i["run"] = true
	# Travel on the road, like a player would: the walkway lane is where the props
	# (crate stacks, bins, parked cars) are.
	if not p.get("lanes", false):
		return i
	var near_block := _near_any(p["x"], road_blocked)
	if near_block and p["lane"] != Lanes.GROUND_LANE:
		i["lane"] = _lane_step(p, Lanes.GROUND_LANE)
		i["why"] = "advance: road blocked, use the walkway"
	# Only from the street itself: the game refuses lane steps from raised ground,
	# and a refused step held every frame would also block the unstick jump.
	elif not near_block and p["lane"] == Lanes.GROUND_LANE and p.get("on_street", true):
		i["lane"] = _lane_step(p, Lanes.GROUND_LANE + 1)
		i["why"] = "advance: take the road"
	return i


## Escalating escape when the player wants to move but is not getting anywhere:
## jump in place, then a lane step (road -> walkway, remembering the block), then
## back off a random (seeded) distance and take a running jump. The random back-off
## is a search: each attempt launches from a different spot, which is what finds a
## staircase like sidewalk ledge -> bin -> crate tops. Mutates `intent`.
static func _unstick(p: Dictionary, intent: Dictionary, dt: float, mem: Dictionary) -> Dictionary:
	if mem["backoff_s"] > 0.0:
		mem["backoff_s"] -= dt
		intent["x"] = -mem["backoff_dir"]
		intent["jump"] = false
		intent["why"] = "unstick: back off"
		if mem["backoff_s"] <= 0.0:
			mem["jump_next"] = true
		return intent
	if mem["jump_next"] and intent["x"] != 0:
		mem["jump_next"] = false
		intent["jump"] = true
		intent["why"] = "unstick: running jump"
		return intent
	# A lane escape is HELD until the player actually changes lane: one request
	# made while airborne is refused by Player.try_change_lane and simply lost.
	if mem["lane_req"] != 0:
		mem["lane_req_s"] -= dt
		if p["lane"] != mem["lane_req_from"] or p.get("changing_lane", false) or mem["lane_req_s"] <= 0.0:
			mem["lane_req"] = 0
		else:
			intent["lane"] = mem["lane_req"]
			intent["jump"] = false
			intent["why"] = "unstick: lane step"
			return intent
	if intent["x"] == 0 and not intent["attack"] and not (intent["why"] in LEGIT_IDLE):
		mem["idle_s"] += dt
	else:
		mem["idle_s"] = 0.0
	if mem["idle_s"] >= IDLE_MAX_S:
		intent["x"] = int(p.get("facing", 1))
		intent["why"] = "unstick: idle too long"
		if mem["idle_s"] >= IDLE_MAX_S + WANDER_S:
			mem["idle_s"] = 0.0
	var x: float = p["x"]
	var moving: bool = intent["x"] != 0 and not (str(p.get("state", "")) in ["KnockbackState", "AttackState"])
	if not moving or not is_finite(mem["anchor_x"]) or absf(x - mem["anchor_x"]) > PROGRESS_PX:
		mem["anchor_x"] = x
		mem["stuck_s"] = 0.0
		mem["lane_tried"] = false
		return intent
	mem["stuck_s"] += dt
	var s: float = mem["stuck_s"]
	if s >= STUCK_BACK_S:
		var rng: RandomNumberGenerator = mem["rng"]
		mem["backoff_s"] = rng.randf_range(BACKOFF_MIN_S, BACKOFF_MAX_S)
		mem["backoff_dir"] = intent["x"]
		mem["stuck_s"] = 0.0
		mem["lane_tried"] = false
		intent["why"] = "unstick: back off"
	elif s >= STUCK_LANE_S and not mem["lane_tried"] and p.get("lanes", false):
		mem["lane_tried"] = true
		var step := 0
		if p["lane"] != Lanes.GROUND_LANE:
			mem["road_blocked"].append(x)
			step = -1
			intent["why"] = "unstick: road blocked at x%d" % roundi(x)
		elif not _near_any(x, mem["road_blocked"]):
			step = 1
			intent["why"] = "unstick: change lane"
		if step != 0:
			mem["lane_req"] = step
			mem["lane_req_from"] = p["lane"]
			mem["lane_req_s"] = LANE_REQ_S
			intent["lane"] = step
	elif s >= STUCK_JUMP_S and s < STUCK_LANE_S - LAND_BEFORE_LANE_S and intent["lane"] == 0:
		# Stop jumping before the lane rung so the player has landed by then:
		# Player.try_change_lane refuses airborne players.
		intent["jump"] = true
		intent["why"] = "unstick: jump"
	return intent


static func _near_any(x: float, xs: Array) -> bool:
	return xs.any(func(bx: float) -> bool: return absf(x - bx) < ROAD_BLOCK_SPAN)


static func _side(dx: float) -> int:
	return 1 if dx > 0.0 else -1


static func _lane_step(p: Dictionary, lane: int) -> int:
	if p.get("changing_lane", false):
		return 0
	return signi(lane - int(p["lane"]))


static func _nearest_x(p: Dictionary, items: Array, max_dx: float) -> Dictionary:
	var best := {}
	var best_d := INF
	for it: Dictionary in items:
		var d := absf(it["x"] - p["x"])
		if d <= max_dx and d < best_d:
			best = it
			best_d = d
	return best


## Seeded random button mashing: finds crashes and soft-locks, not progress.
static func _monkey(dt: float, mem: Dictionary) -> Dictionary:
	mem["monkey_left"] -= dt
	if mem["monkey_left"] > 0.0:
		return mem["monkey"]
	var rng: RandomNumberGenerator = mem["rng"]
	var i := idle("monkey")
	var r := rng.randf()
	i["x"] = 1 if r < 0.55 else (-1 if r < 0.8 else 0)
	i["run"] = rng.randf() < 0.5
	i["jump"] = rng.randf() < 0.2
	i["attack"] = rng.randf() < 0.35
	i["crouch"] = rng.randf() < 0.05
	var l := rng.randf()
	i["lane"] = 1 if l < 0.08 else (-1 if l < 0.16 else 0)
	mem["monkey"] = i
	mem["monkey_left"] = rng.randf_range(0.15, 0.5)
	return i
