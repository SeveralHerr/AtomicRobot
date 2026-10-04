extends RefCounted
class_name CutsceneShots

## The street's micro cut scenes as data: where the camera goes, how long it takes,
## and what the caption says. The play camera sits at zoom 2.5 to keep the fight
## readable, which crops the level art down to a slice — each scene pulls back to
## frame one landmark whole, then hands the camera back to the player.
##
## A shot glides the camera to `at` / `zoom` over `move` seconds (0 = cut), then
## holds `hold` seconds. Captions and effects fire at seconds from the scene start.

## Play camera (player.tscn Camera2D): zoom, offset from the player, bottom limit.
const PLAY_ZOOM := 2.5
const PLAY_OFFSET := Vector2(0, 20)
const LIMIT_BOTTOM := 96.0
## The design viewport (project.godot); cut scenes frame against it.
const VIEW := Vector2(1280, 800)
## Street triggers wait for the walk-in to be quiet: no live enemy this close.
const CLEAR_RADIUS := 700.0
## The title must stay up at least this long before the glide back takes it away.
const READ_S := 1.3
## Past trigger_x by more than this, the moment has gone (a fight carried the player
## on through): skip the scene rather than yank the camera back.
const TRIGGER_WINDOW := 900.0

const SCENES := {
	# The story the old text screen told, told over the street instead: open close
	# on the meter maids ticketing a car, pull back and dolly left down the block to
	# the shop, push in on the player in front of it.
	"opening": {
		"trigger_x": -INF,
		"shots": [
			# Close on the two maids ticketing the red car (car x ~1225-1340, maids
			# authored right behind it in atomic_robot_area.tscn).
			{"at": Vector2(1320, -104), "zoom": 2.0, "move": 0.0, "hold": 0.5},
			{"at": Vector2(1325, -98), "zoom": 2.25, "move": 2.6, "hold": 1.4},
			# Pull back and dolly left down the block to the shop.
			{"at": Vector2(-258, -262), "zoom": 1.15, "move": 3.2, "hold": 0.4},
			{"at": Vector2(-268, -166), "zoom": 1.55, "move": 2.0, "hold": 1.3},
		],
		"captions": [
			{"at": 0.4, "kicker": "PARKING ENFORCEMENT HAS REACHED", "title": "NEW LEVELS...", "tint": ComicStyle.BLUE},
			{"at": 2.8, "kicker": "ISSUING TICKETS", "title": "AROUND THE CLOCK!", "tint": ComicStyle.RED},
			{"at": 6.4, "kicker": "SIOUX FALLS, DOWNTOWN.", "title": "ATOMIC ROBOT TATTOO", "tint": ComicStyle.RED},
			{"at": 8.75, "kicker": "JOIN THEIR FIGHT TO KEEP DOWNTOWN", "title": "BALANCED!", "tint": ComicStyle.PLUM},
		],
		# A ticket slapped on the red car as AROUND THE CLOCK! lands.
		"pops": [{"at": 3.55, "pos": Vector2(1284, -22), "kind": &"ticket"}],
		# A gust through the shop's trees as the camera arrives.
		"gust_at": 6.2, "gust": Vector2(-258, -40),
	},
	"arch": {
		"trigger_x": 6250.0,
		"shots": [
			{"at": Vector2(6420, -272), "zoom": 1.1, "move": 1.2, "hold": 0.0},
			{"at": Vector2(6720, -268), "zoom": 1.1, "move": 2.4, "hold": 0.0},
			# On past the arch's right leg to the statue, pushing in.
			{"at": Vector2(7150, -205), "zoom": 1.6, "move": 1.8, "hold": 0.6},
		],
		"captions": [
			{"at": 1.0, "kicker": "OVER THE BIG SIOUX...", "title": "THE ARCH", "tint": ComicStyle.BLUE},
		],
	},
	"council": {
		"trigger_x": 8150.0,
		"shots": [
			{"at": Vector2(8675, -156), "zoom": 1.6, "move": 1.0, "hold": 0.0},
			{"at": Vector2(8675, -236), "zoom": 1.22, "move": 2.4, "hold": 1.5},
		],
		"captions": [
			{"at": 2.6, "kicker": "THE LAST STOP...", "title": "CITY COUNCIL", "tint": ComicStyle.PLUM},
		],
		# Storm: the street dims to dusk, then lightning lands as the caption does.
		"dusk": Color(0.84, 0.8, 0.94), "thunder_at": 3.35,
	},
}

## Street scenes in trigger order (the opening plays on level load, not by position).
const STREET := ["arch", "council"]


static func scene(id: String) -> Dictionary:
	return SCENES[id]


## Seconds from the first frame to the end of the last shot's hold.
static func duration(id: String) -> float:
	var t := 0.0
	for s: Dictionary in SCENES[id]["shots"]:
		t += s["move"] + s["hold"]
	return t


## Half the world area a camera at `zoom` shows.
static func half_view(zoom: float) -> Vector2:
	return VIEW * 0.5 / zoom


## The centre a camera at `zoom` really shows when aimed at `center`: Camera2D's
## bottom limit pushes it up so the view never dips under the road.
static func clamp_center(center: Vector2, zoom: float) -> Vector2:
	return Vector2(center.x, minf(center.y, LIMIT_BOTTOM - half_view(zoom).y))


## Where the play camera sits for a player at `player_pos` — the cut scene glides
## back to exactly this, so the hand-off doesn't jump.
static func play_center(player_pos: Vector2) -> Vector2:
	return clamp_center(player_pos + PLAY_OFFSET, PLAY_ZOOM)


## Seconds from the scene start until caption `i`'s title has landed. A caption that
## replaces another first lifts the old box away.
static func title_lands_after(id: String, i: int) -> float:
	var c: Dictionary = SCENES[id]["captions"][i]
	return c["at"] + (CaptionCard.SWAP if i > 0 else 0.0) + CaptionCard.lands_after(c["kicker"])


## Until when caption `i` has the screen: the next caption, or the scene's end.
static func caption_until(id: String, i: int) -> float:
	var caps: Array = SCENES[id]["captions"]
	return caps[i + 1]["at"] if i + 1 < caps.size() else duration(id)


## No live enemy close enough to matter, and no scripted fight mid-way (a door
## squad between waves has nobody alive, but its next wave and banner are coming).
static func is_quiet(player_x: float, enemy_xs: Array, fight_on: bool) -> bool:
	if fight_on:
		return false
	for x: float in enemy_xs:
		if absf(x - player_x) < CLEAR_RADIUS:
			return false
	return true


## Seconds the street must stay quiet first: a door's STREET CLEAR! payoff lands and
## gets a beat on its own; the cut scene clears it as the camera pulls back. Not
## its full hold — the next door (x 6949) is ~3s' walk past the arch's mark.
const PAYOFF_BEAT := 1.0


static func quiet_needed() -> float:
	return EncounterAnnouncer.SLAM_IN + PAYOFF_BEAT


## Street trigger: the player has walked up to `trigger_x` (not long past it) and
## the street has been quiet for `quiet_for` seconds.
static func should_trigger(player_x: float, trigger_x: float, quiet_for: float) -> bool:
	if player_x < trigger_x or player_x > trigger_x + TRIGGER_WINDOW:
		return false
	return quiet_for >= quiet_needed()
