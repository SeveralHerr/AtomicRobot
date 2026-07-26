extends RefCounted

# Headless tests for the pure decision rules behind enemy combat:
#   - Lanes.can_engage      — who can hit whom across the depth axis
#   - AttackPlayerState.release_frame_for — where in a clip a swing connects
#   - Enemy.leading_ray_is_left           — which ledge ray gates a move
#
# Each of these was a live bug fixed by extraction: lane parity silenced window
# and platform maids, a hardcoded frame index never matched the shorter of the two
# shipped melee clips, and a two-sided ledge check froze enemies against a ledge.

var _T
const L = preload("res://scripts/lane_system.gd")
const ATTACK = preload("res://scripts/states/attack_player_state.gd")
const ENEMY = preload("res://scripts/enemy.gd")


# ---------------------------------------------------------------- can_engage

func test_same_lane_engages() -> String:
	for lane in range(L.BACK_LANE, L.FRONT_LANE + 1):
		if not L.can_engage(lane, lane, false):
			return "lane %d should engage itself" % lane
	return ""


func test_cross_lane_does_not_engage() -> String:
	var r: String = _T.assert_false(
		L.can_engage(L.BACK_LANE, L.FRONT_LANE, false), "back cannot reach front")
	if r != "":
		return r
	return _T.assert_false(
		L.can_engage(L.GROUND_LANE, L.GROUND_LANE + 1, false), "adjacent lanes do not connect")


## Window/platform maids fire down onto the street; their coins are lane-agnostic.
func test_lane_locked_attackers_reach_every_lane() -> String:
	for lane in range(L.BACK_LANE, L.FRONT_LANE + 1):
		if not L.can_engage(L.GROUND_LANE, lane, true):
			return "lane-locked attacker should reach lane %d" % lane
	return ""


func test_lane_lock_does_not_make_a_grounded_maid_omnipresent() -> String:
	# Sanity check the flag is the only thing relaxing the rule — a normal maid on
	# the walkway must still miss a player who stepped toward the camera.
	return _T.assert_false(
		L.can_engage(L.GROUND_LANE, L.FRONT_LANE, false), "unlocked maid stays lane-bound")


# ------------------------------------------------------------ attack_category

## Globals' attack-slot manager keys its pools off `enemy.attack_category` and reads it
## dynamically off whatever object it is handed, so renaming or dropping the property
## would not raise a compile error — every enemy would just silently fall into whichever
## pool the fallback picks and the per-category caps would stop meaning anything. Pin the
## declaration and the base default (plain Enemy throws coins, so it is ranged; the melee
## subclasses are the ones that override).
func test_enemy_declares_attack_category_defaulting_to_ranged() -> String:
	var script: Script = ENEMY
	var declared: bool = false
	for p: Dictionary in script.get_script_property_list():
		if str(p.get("name", "")) == "attack_category":
			declared = true
			var r: String = _T.assert_eq(int(p.get("type", TYPE_NIL)), TYPE_STRING, "attack_category must be a String")
			if r != "":
				return r
	if not declared:
		return "Enemy no longer declares an `attack_category` property — the slot pools key off it"
	return _T.assert_eq(
		script.get_property_default_value("attack_category"), "ranged", "base Enemy defaults to the ranged pool")


# --------------------------------------------------------- release_frame_for

func test_release_frame_uses_the_hint_when_the_clip_is_long_enough() -> String:
	return _T.assert_eq(ATTACK.release_frame_for(6, 11), 6, "11-frame clip honours hint 6")


## The exact shape of the old bug: hint 7 against a 7-frame clip (indices 0..6)
## could never match, so the swing never closed and the maid stood frozen.
func test_release_frame_clamps_into_a_short_clip() -> String:
	var r: String = _T.assert_eq(ATTACK.release_frame_for(7, 7), 6, "hint past the end clamps to last frame")
	if r != "":
		return r
	return _T.assert_eq(ATTACK.release_frame_for(6, 8), 6, "8-frame melee clip honours hint 6")


func test_release_frame_is_always_a_valid_index() -> String:
	for count in range(1, 16):
		for hint in range(-2, 20):
			var f: int = ATTACK.release_frame_for(hint, count)
			if f < 0 or f >= count:
				return "release_frame_for(%d, %d) = %d is out of range" % [hint, count, f]
	return ""


func test_release_frame_survives_an_empty_clip() -> String:
	return _T.assert_eq(ATTACK.release_frame_for(6, 0), 0, "no frames still yields a usable index")


## The shipped sprite sets are the real inputs — assert the states' hints land on
## frames that exist in both, so swapping a maid's sprite set can't silently
## disarm her.
func test_shipped_maid_clips_resolve_to_real_frames() -> String:
	var sets := {
		"metermaid": "res://sprites/metermaid_sprite_frames.tres",
		"metermaid_melee": "res://sprites/metermaid_melee_sprite_frames.tres",
	}
	for set_name in sets:
		var frames: SpriteFrames = load(sets[set_name])
		if frames == null:
			return "could not load sprite set %s" % set_name
		for clip in ["attack", "melee"]:
			if not frames.has_animation(clip):
				return "%s is missing the '%s' clip" % [set_name, clip]
			var count: int = frames.get_frame_count(clip)
			if count <= 0:
				return "%s '%s' has no frames" % [set_name, clip]
			var release: int = ATTACK.release_frame_for(6, count)
			if release >= count:
				return "%s '%s' release frame %d is past the clip" % [set_name, clip, release]
			# The swing is closed out by animation_finished, which a looping clip
			# never emits — that would park the enemy in its attack state forever.
			if frames.get_animation_loop(clip):
				return "%s '%s' must not loop: the attack state ends on animation_finished" % [set_name, clip]
	return ""


## Every clip the enemy states ask for by name must exist, or play() errors and
## the state silently does nothing.
func test_shipped_maid_sets_have_every_clip_the_states_play() -> String:
	var required := ["idle", "walk", "attack", "melee", "death", "refill"]
	for path in ["res://sprites/metermaid_sprite_frames.tres", "res://sprites/metermaid_melee_sprite_frames.tres"]:
		var frames: SpriteFrames = load(path)
		if frames == null:
			return "could not load %s" % path
		for clip in required:
			if not frames.has_animation(clip):
				return "%s is missing the '%s' clip" % [path.get_file(), clip]
	return ""


# -------------------------------------------------------- leading_ray_is_left

## Facing right: the "left" ray sits at a negative offset, so a rightward move is
## gated by the right ray.
func test_leading_ray_when_facing_right() -> String:
	var r: String = _T.assert_false(ENEMY.leading_ray_is_left(-25.0, 1), "moving right uses the right ray")
	if r != "":
		return r
	return _T.assert_true(ENEMY.leading_ray_is_left(-25.0, -1), "moving left uses the left ray")


## Facing left mirrors the body, so the node named "left" is now on the world
## right — the choice must follow the world offset, not the node name.
func test_leading_ray_when_facing_left_is_mirrored() -> String:
	var r: String = _T.assert_true(ENEMY.leading_ray_is_left(25.0, 1), "mirrored: 'left' ray leads a rightward move")
	if r != "":
		return r
	return _T.assert_false(ENEMY.leading_ray_is_left(25.0, -1), "mirrored: 'right' ray leads a leftward move")


func test_leading_ray_always_picks_the_side_being_moved_toward() -> String:
	for offset in [-25.0, 25.0]:
		for dir in [-1, 1]:
			var picked_left: bool = ENEMY.leading_ray_is_left(offset, dir)
			var picked_offset: float = offset if picked_left else -offset
			if signf(picked_offset) != signf(float(dir)):
				return "offset %.0f dir %d picked the trailing ray" % [offset, dir]
	return ""
