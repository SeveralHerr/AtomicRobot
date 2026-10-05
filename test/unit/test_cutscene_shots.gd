extends RefCounted

## CutsceneShots is the street cut scenes' table. These pin framing rules every shot
## must keep (never look under the road) and the trigger rule, not the numbers.

var _T

const PLAYER_SCENE := preload("res://scenes/player.tscn")


func _all_shots() -> Array:
	var out := []
	for id: String in CutsceneShots.SCENES:
		for s: Dictionary in CutsceneShots.scene(id)["shots"]:
			out.append([id, s])
	return out


func test_every_shot_stays_above_the_road() -> String:
	for pair in _all_shots():
		var s: Dictionary = pair[1]
		var shown := CutsceneShots.clamp_center(s["at"], s["zoom"])
		if shown != s["at"]:
			return "%s shot at %s zoom %s dips under the road (camera would sit at %s)" % [pair[0], s["at"], s["zoom"], shown]
	return ""


func test_every_shot_pulls_back_from_the_play_camera() -> String:
	for pair in _all_shots():
		if pair[1]["zoom"] >= CutsceneShots.PLAY_ZOOM:
			return "%s shot zoom %s shows no more art than play" % [pair[0], pair[1]["zoom"]]
	return ""


## The table's copy of the play camera must be the real one, or the glide back
## lands off the player's framing and the hand-off jumps.
func test_play_camera_constants_match_player_scene() -> String:
	var p: Node = PLAYER_SCENE.instantiate()
	var cam: Camera2D = p.get_node("Camera2D")
	var r: String = _T.assert_float_eq(cam.zoom.x, CutsceneShots.PLAY_ZOOM, 0.001, "zoom")
	if r == "":
		r = _T.assert_eq(cam.position, CutsceneShots.PLAY_OFFSET, "offset")
	if r == "":
		r = _T.assert_float_eq(float(cam.limit_bottom), CutsceneShots.LIMIT_BOTTOM, 0.001, "limit_bottom")
	p.free()
	return r


func test_every_title_stays_up_long_enough_to_read() -> String:
	for id: String in CutsceneShots.SCENES:
		for i in CutsceneShots.scene(id)["captions"].size():
			var lands := CutsceneShots.title_lands_after(id, i)
			var gone := CutsceneShots.caption_until(id, i)
			if lands + CutsceneShots.READ_S > gone:
				return "%s caption %d lands at %.2fs, gone at %.2fs: under %.1fs to read" % [id, i, lands, gone, CutsceneShots.READ_S]
	return ""


func test_captions_run_in_order() -> String:
	for id: String in CutsceneShots.SCENES:
		var last := -1.0
		for c: Dictionary in CutsceneShots.scene(id)["captions"]:
			if c["at"] <= last:
				return "%s caption at %.1fs is not after the one before" % [id, c["at"]]
			last = c["at"]
	return ""


## The old text screen's story now lives in the opening; none of it may get lost.
func test_opening_tells_the_story() -> String:
	var said := ""
	for c: Dictionary in CutsceneShots.scene("opening")["captions"]:
		said += " " + c["kicker"] + " " + c["title"]
	for word in ["PARKING ENFORCEMENT", "TICKETS", "AROUND THE CLOCK", "ATOMIC ROBOT TATTOO", "FIGHT", "DOWNTOWN", "BALANCED", "SIOUX FALLS"]:
		if not word in said:
			return "opening never says %s" % word
	return ""


func test_lands_after_grows_with_the_kicker() -> String:
	return _T.assert_gt(CaptionCard.lands_after("A LONGER KICKER"), CaptionCard.lands_after("SHORT"), "typing time counts")


func test_street_is_not_quiet_while_a_scripted_fight_is_on() -> String:
	return _T.assert_false(CutsceneShots.is_quiet(1000.0, [], true), "door squad between waves")


func test_street_is_quiet_with_only_far_enemies() -> String:
	return _T.assert_true(CutsceneShots.is_quiet(1000.0, [1000.0 + CutsceneShots.CLEAR_RADIUS + 1.0], false), "far enemy only")


func test_street_is_not_quiet_with_an_enemy_close_behind() -> String:
	return _T.assert_false(CutsceneShots.is_quiet(1000.0, [1000.0 - CutsceneShots.CLEAR_RADIUS + 1.0], false), "just inside the radius")


func test_quiet_lets_the_street_clear_payoff_land_first() -> String:
	return _T.assert_gt(CutsceneShots.quiet_needed(), EncounterAnnouncer.SLAM_IN + 0.5, "payoff lands and is seen before the scene")


func test_street_triggers_sit_left_of_their_landmark_in_order() -> String:
	var last := -INF
	for id: String in CutsceneShots.STREET:
		var spec := CutsceneShots.scene(id)
		var x: float = spec["trigger_x"]
		if x <= last:
			return "%s trigger %s is not after the previous one" % [id, x]
		last = x
		var last_shot: Dictionary = spec["shots"][-1]
		if x >= last_shot["at"].x:
			return "%s fires at %s, already past its landmark at %s" % [id, x, last_shot["at"].x]
	return ""


func test_play_center_clamps_like_the_play_camera() -> String:
	var c := CutsceneShots.play_center(Vector2(500, -21))
	var r: String = _T.assert_float_eq(c.x, 500.0, 0.001, "x follows the player")
	if r != "":
		return r
	# Zoom 2.5 shows 160px above and below centre; the bottom limit is 96.
	return _T.assert_float_eq(c.y, CutsceneShots.LIMIT_BOTTOM - 160.0, 0.001, "y pushed up by limit_bottom")


func _q() -> float:
	return CutsceneShots.quiet_needed()


func test_trigger_waits_for_the_player_to_reach_it() -> String:
	return _T.assert_false(CutsceneShots.should_trigger(999.0, 1000.0, _q()), "one px short")


func test_trigger_fires_at_the_mark_once_quiet_long_enough() -> String:
	return _T.assert_true(CutsceneShots.should_trigger(1000.0, 1000.0, _q()), "at the mark, quiet")


func test_trigger_waits_out_the_quiet_window() -> String:
	return _T.assert_false(CutsceneShots.should_trigger(1000.0, 1000.0, _q() - 0.05), "fight only just ended")


func test_trigger_gives_up_once_long_past() -> String:
	var past := 1000.0 + CutsceneShots.TRIGGER_WINDOW + 1.0
	var r: String = _T.assert_false(CutsceneShots.should_trigger(past, 1000.0, _q()), "beyond the window")
	if r != "":
		return r
	return _T.assert_true(CutsceneShots.should_trigger(past - 2.0, 1000.0, _q()), "still inside the window")


## Player report: story scenes "skipped for no reason". A fight that carried the player
## past the mark used to drop the scene for good; now it waits for quiet, then plays
## anyway (the cut scene freezes the fight) before the player can walk out of reach.
func test_trigger_forces_a_scene_still_waiting_on_a_busy_street() -> String:
	var at := 1000.0 + CutsceneShots.FORCE_AFTER
	var r: String = _T.assert_true(CutsceneShots.should_trigger(at, 1000.0, 0.0), "busy street, at the force point")
	if r != "":
		return r
	return _T.assert_false(CutsceneShots.should_trigger(at - 1.0, 1000.0, 0.0), "busy street, still before it: keep waiting")


func test_force_point_sits_inside_the_trigger_window() -> String:
	return _T.assert_gt(CutsceneShots.TRIGGER_WINDOW, CutsceneShots.FORCE_AFTER, "forced before the window gives up")


## Derived from the level: every street scene is forced before the next one's mark and
## before the boss door, or walking on still loses it.
func test_every_street_scene_is_forced_before_the_player_can_leave() -> String:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var door_left := INF
	for n in main.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s != null and s.resource_path.ends_with("final_boss_enter.gd"):
			for c in n.find_children("*", "CollisionShape2D", true, false):
				var cs := c as CollisionShape2D
				var rect := cs.shape.get_rect()
				var left := _global_x(cs) + rect.position.x * absf(_global_scale_x(cs))
				door_left = minf(door_left, left)
	main.free()
	var r: String = _T.assert_true(door_left < INF, "found the boss door in main.tscn")
	if r != "":
		return r
	var ids: Array = CutsceneShots.STREET
	for i in ids.size():
		var force_x: float = CutsceneShots.scene(ids[i])["trigger_x"] + CutsceneShots.FORCE_AFTER
		r = _T.assert_gt(door_left - 100.0, force_x, "%s forced before the boss door" % ids[i])
		if r != "":
			return r
		if i + 1 < ids.size():
			r = _T.assert_gt(CutsceneShots.scene(ids[i + 1])["trigger_x"], force_x, "%s forced before the next mark" % ids[i])
			if r != "":
				return r
	return ""


## Position/scale through the parent chain of a node that is not in the tree.
func _global_x(n: Node) -> float:
	var node: Node = n
	var xform := Transform2D.IDENTITY
	while node != null:
		if node is Node2D:
			xform = (node as Node2D).transform * xform
		elif node is CanvasLayer:
			break
		node = node.get_parent()
	return xform.origin.x


func _global_scale_x(n: Node) -> float:
	var s := 1.0
	var node: Node = n
	while node != null:
		if node is Node2D:
			s *= (node as Node2D).scale.x
		node = node.get_parent()
	return s
