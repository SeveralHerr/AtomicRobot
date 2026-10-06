extends StreetObjective
class_name SnatchChase

## Side job "THIEF!": a customer's car keys lie glinting on the walkway; once the player
## has walked past them, a maid darts in from the far side, scoops them up and runs —
## BACK the way the player came (flee_dir), weaving between the road lanes. One blow
## (or a passing car) and she drops them: the keys fly home and pay out. Let her get
## escape_dist past the spot, or let the clock run out, and she is gone with them.
##
## The clock only runs once she has the keys; the start callout slams as she appears,
## so the player turns round before the grab instead of after it.

const GOAL := "CATCH THE THIEF!"
const START_TITLE := "THIEF!"
const START_SUB := "SHE SWIPED A CUSTOMER'S KEYS!"
const WIN_TITLE := "KEYS RETURNED!"
const WIN_WORD := "GOTCHA!"
const GRAB_WORD := "YOINK!"
const MISS_TITLE := "SHE GOT AWAY!"
const MISS_SUB := "SOMEBODY'S TAKING THE BUS HOME"
const STAMP_WIN := "GOT 'EM!"
const STAMP_MISS := "GONE!"
## The start stripe is glanced, not read: the chase is already on under it.
const START_HOLD := 1.3
## Keys ride this far above the thief's origin (over her head).
const CARRY := Vector2(0, -40)
## Seconds the keys take to arc back to the player, and the arc's height.
const RETURN_S := 0.45
const RETURN_ARC := 60.0
## Seconds an escaping thief takes to fade into the distance.
const ESCAPE_FADE_S := 0.5

## Where the keys lie (world x, on the walkway).
@export var keys_x: float = 1700.0
## The way she runs with them: -1 back toward the start of the street.
@export var flee_dir: int = -1
## She is gone once this far past the keys' spot in flee_dir (world px).
@export var escape_dist: float = 1000.0
## She appears this far past the keys on the flee side: off screen, but close.
@export var spawn_dist: float = 330.0

var keys: KeysProp
var thief: Enemy
var grabbed: bool = false
var _thief_hp: int = 0


func _init() -> void:
	id = "snatch_chase"
	time_limit = 11.0
	reward_points = 500


## Pure escape rule: `thief_x` is escape_dist past `from_x` in `dir`.
static func escaped(thief_x: float, from_x: float, dir: int, dist: float) -> bool:
	return (thief_x - from_x) * signf(dir) >= dist


## Pure catch rule: a blow landed (health went down) or she is dead.
static func caught(hp_now: int, hp_start: int, dead: bool) -> bool:
	return dead or hp_now < hp_start


func _process(delta: float) -> void:
	# Lay the keys down as soon as the street line is known, so they are already there
	# when the player walks past.
	if keys == null and phase == Phase.WAITING:
		var p := _player()
		if p != null and p.lane_floor_y != INF:
			_lay_keys(p.lane_floor_y)
	super(delta)


func _lay_keys(floor_y: float) -> void:
	keys = KeysProp.new()
	keys.name = "Keys"
	add_child(keys)
	keys.global_position = Vector2(keys_x, floor_y - KeysProp.LIFT)


func _begin() -> void:
	var scene := get_tree().current_scene
	var x := keys_x + flee_dir * spawn_dist
	thief = EnemySpawner.spawn_enemy_at(scene, player, x, Lanes.GROUND_LANE, true)
	if thief == null:
		finish(false)
		return
	# Never purged for distance: running off is HER way out, judged by escaped().
	thief.persist = true
	_thief_hp = thief.health
	announcer.callout(START_TITLE, START_SUB, ComicStyle.RED, false, START_HOLD)
	hud.open(GOAL, ComicStyle.RED)
	hud.set_arrow(flee_dir)
	_arm_thief.call_deferred()


## spawn_enemy_at defers the add: wait for her _ready, then make her the thief.
func _arm_thief() -> void:
	await get_tree().process_frame
	if phase != Phase.RUNNING or not is_instance_valid(thief):
		return
	var st := ThiefState.new(thief)
	st.grab_x = keys_x
	st.flee_dir = flee_dir
	st.rng.seed = hash(id)
	st.on_grab = _on_grab
	thief.enemy_state_machine.add_state("ThiefState", st)
	thief.enemy_state_machine.change_state("ThiefState")


func _on_grab() -> void:
	grabbed = true
	if is_instance_valid(keys):
		keys.reparent(thief, false)
		keys.position = CARRY
	ComicPopup.spawn(self, thief.global_position + Vector2(0, -30), &"snatch", GRAB_WORD)


func _clock_running() -> bool:
	return grabbed


func _tick(_delta: float) -> void:
	if not is_instance_valid(thief):
		# Freed under us (kill box): she is not coming back.
		finish(false)
		return
	if caught(thief.health, _thief_hp, thief.is_dead):
		finish(true)
		return
	var tx := thief.global_position.x
	if grabbed and escaped(tx, keys_x, flee_dir, escape_dist):
		finish(false)
		return
	hud.set_status(str(ceili(time_left)) if grabbed else "")
	var dx := tx - player.global_position.x
	hud.set_arrow(signi(dx) if absf(dx) > 40.0 else 0)


func _stamp_word(won: bool) -> String:
	return STAMP_WIN if won else STAMP_MISS


func _payoff(won: bool) -> void:
	if won:
		announcer.callout(WIN_TITLE, "+%d" % reward_points, WIN_TINT, true)
		var at := thief.global_position if is_instance_valid(thief) else player.global_position
		ComicPopup.spawn(self, at + Vector2(0, -30), &"job", WIN_WORD)
	else:
		announcer.callout(MISS_TITLE, MISS_SUB, MISS_TINT)


func _cleanup(won: bool) -> void:
	if won:
		_return_keys()
		# Caught, she is just a maid again — and a cross one.
		if is_instance_valid(thief) and not thief.is_dead:
			thief.persist = false
			thief.enemy_state_machine.change_state("ChasePlayerState")
		return
	if player != null and player.is_dead:
		return  # the death beat owns the screen; leave the street as it is
	if is_instance_valid(thief) and not thief.is_dead:
		_vanish(thief)
	elif is_instance_valid(keys) and not grabbed:
		_vanish(keys)


## The keys arc out of her hands into the player's and pop.
func _return_keys() -> void:
	if not is_instance_valid(keys) or not is_instance_valid(player):
		return
	var from := keys.global_position
	keys.reparent(self, false)
	keys.global_position = from
	var to := player.global_position + Vector2(0, -24)
	var tw := keys.create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(keys):
			keys.global_position = from.lerp(to, k) + Vector2(0, -RETURN_ARC * 4.0 * k * (1.0 - k)),
		0.0, 1.0, RETURN_S).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(keys.collect)


## She ducks out of the chase: fades into the distance, keys and all.
func _vanish(who: Node2D) -> void:
	who.set_physics_process(false)
	var tw := who.create_tween()
	tw.tween_property(who, "modulate:a", 0.0, ESCAPE_FADE_S)
	tw.tween_callback(who.queue_free)
