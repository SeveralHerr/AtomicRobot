extends StreetObjective
class_name MeterDefense

## Side job "SAVE THE CARS!": customers' cars sit parked at the curb by the meters; as
## the player reaches them, a squad of maids marches in to ticket every one. Each
## maid claims a car, stands at its meter writing (TicketState), and slaps the ticket
## on. A blow pulls her off the car into a fight (her ticket starts over), but left
## alone for grudge_seconds she goes back to writing — only a KO stops her for good.
##
## Outcome: all cars ticketed = miss, at once. Otherwise the job ends when the squad
## is down (or the clock runs out) and pays points_per_car for every car still clean.
## Either way the cars pull out and leave, so the road is clear for traffic again.

const GOAL := "SAVE THE CARS!"
const START_TITLE := "TICKET SWEEP!"
const START_SUB := "THEY'RE AFTER THE CUSTOMERS' CARS!"
const WIN_TITLE := "CARS SAVED!"
const WIN_SUB_ALL := "NOT ONE TICKET!"
const WIN_SUB_SOME := "%d OF %d DRIVE OFF FREE"
const WIN_WORD := "SAVED!"
const MISS_TITLE := "TICKETED!"
const MISS_SUB := "EVERY LAST CAR. OUCH."
const STAMP_WIN := "SAVED!"
const STAMP_MISS := "TICKETED"
const START_HOLD := 1.4
## Cars park this far ahead of the trigger: out of view of a player walking in, so
## they are simply there when the street comes into view.
const PARK_AHEAD := 700.0
## Seconds after the end before the cars pull out (the payoff reads first).
const LEAVE_DELAY := 1.2

## Car centres (world x), parked on the road lane next to the curb.
@export var car_xs: Array[float] = [3140.0, 3330.0, 3540.0]
@export var maid_count: int = 3
## Every 'melee_every'-th maid is a melee maid; the rest throw coins.
@export var melee_every: int = 3
## Seconds a maid stands at a car to write its ticket.
@export var ticket_seconds: float = 3.5
## Seconds a hit maid fights before she goes back to the cars.
@export var grudge_seconds: float = 3.0
## Maids march in from this far past the last car, one every maid_stagger seconds.
@export var spawn_past: float = 320.0
@export var maid_stagger: float = 0.9
@export var points_per_car: int = 300

var cars: Array[ParkedCar] = []
var maids: Array[Enemy] = []
var tickets: int = 0
var _spawned: int = 0
var _hp := {}
var _grudge := {}


func _init() -> void:
	id = "meter_defense"
	trigger_x = 2990.0
	time_limit = 40.0


## Pure outcome rule once the squad is down or time is up: any car left clean wins.
static func outcome(ticketed: int, total: int) -> bool:
	return ticketed < total


## Pure: the clean cars pay out.
static func reward_for(ticketed: int, total: int, per_car: int) -> int:
	return maxi(total - ticketed, 0) * per_car


## Pure: the cars pull in once the player is PARK_AHEAD short of the mark, and not
## once they are past the start window (a job that can no longer start parks nothing).
static func parks_now(px: float, mark: float, dir: int) -> bool:
	var past := (px - mark) * signf(dir)
	return past >= -PARK_AHEAD and past <= START_WINDOW


func _process(delta: float) -> void:
	if cars.is_empty() and phase == Phase.WAITING:
		var p := _player()
		if p != null and p.lane_floor_y != INF and parks_now(p.global_position.x, trigger_x, trigger_dir):
			_park(p.lane_floor_y)
	super(delta)


func _park(floor_y: float) -> void:
	for i in car_xs.size():
		var car := ParkedCar.new(i % 2 == 1)
		car.name = "ParkedCar%d" % i
		add_child(car)
		car.park(car_xs[i], floor_y)
		cars.append(car)


func _ready_to_start(p: Player) -> bool:
	return super(p) and not cars.is_empty()


func _begin() -> void:
	announcer.callout(START_TITLE, START_SUB, ComicStyle.RED, false, START_HOLD)
	hud.open(GOAL, ComicStyle.ORANGE)
	hud.set_pips(cars.size(), 0)
	for i in maid_count:
		get_tree().create_timer(maid_stagger * i, false).timeout.connect(_spawn_maid.bind(i))


func _spawn_maid(i: int) -> void:
	if phase != Phase.RUNNING or player == null:
		return
	var x := _far_car_x() + trigger_dir * (spawn_past + i * 24.0)
	var melee := melee_every > 0 and (i + 1) % melee_every == 0
	var maid: Enemy = EnemySpawner.spawn_enemy_at(get_tree().current_scene, player, x, Lanes.GROUND_LANE, melee)
	_spawned += 1
	if maid == null:
		return
	# Never purged for distance: a player who walks off leaves her to ticket in peace
	# (and loses the cars), instead of winning the job by her vanishing.
	maid.persist = true
	maids.append(maid)
	_arm_maid.call_deferred(maid)


func _far_car_x() -> float:
	var far := car_xs[0]
	for x in car_xs:
		if (x - far) * trigger_dir > 0.0:
			far = x
	return far


## spawn_enemy_at defers the add: wait for her _ready, then send her to the cars.
func _arm_maid(maid: Enemy) -> void:
	await get_tree().process_frame
	if not is_instance_valid(maid) or maid.is_dead:
		return
	var st := TicketState.new(maid)
	st.job = self
	st.write_s = ticket_seconds
	maid.enemy_state_machine.add_state("TicketState", st)
	_hp[maid] = maid.health
	if phase == Phase.RUNNING:
		maid.enemy_state_machine.change_state("TicketState")


## The nearest clean car nobody else is writing on (or any clean car), claimed for `maid`.
func claim_car(maid: Enemy) -> ParkedCar:
	var best: ParkedCar = null
	var best_d := INF
	for pass_free in [true, false]:
		for car in cars:
			if not is_instance_valid(car) or car.ticketed:
				continue
			if pass_free and car.claimed_by != null and is_instance_valid(car.claimed_by) and car.claimed_by != maid:
				continue
			var d := absf(car.curb_x() - maid.global_position.x)
			if d < best_d:
				best_d = d
				best = car
		if best != null:
			break
	if best != null:
		best.claimed_by = maid
	return best


func on_ticket(car: ParkedCar) -> void:
	if phase != Phase.RUNNING:
		return
	car.ticket()
	tickets += 1
	hud.set_pips(cars.size(), tickets)
	if tickets >= cars.size():
		_end()


func _tick(delta: float) -> void:
	var alive := 0
	for maid in maids:
		if not is_instance_valid(maid) or maid.is_dead:
			continue
		alive += 1
		_watch_grudge(maid, delta)
	if _spawned >= maid_count and alive == 0:
		_end()


## A blow sends her after the player; left alone long enough, she goes back to work.
func _watch_grudge(maid: Enemy, delta: float) -> void:
	if not _hp.has(maid):
		return  # not armed yet
	var sm := maid.enemy_state_machine
	if maid.health < int(_hp[maid]):
		_hp[maid] = maid.health
		_grudge[maid] = grudge_seconds
		if sm.current_state is TicketState:
			sm.change_state("ChasePlayerState")
		return
	if not _grudge.has(maid):
		return
	_grudge[maid] = float(_grudge[maid]) - delta
	if float(_grudge[maid]) <= 0.0 and sm.current_state is ChasePlayerState:
		_grudge.erase(maid)
		sm.change_state("TicketState")


func _on_time_up() -> void:
	_end()


func _watchdog_outcome() -> bool:
	return outcome(tickets, cars.size())


func _end() -> void:
	reward_points = reward_for(tickets, cars.size(), points_per_car)
	finish(outcome(tickets, cars.size()))


func _stamp_word(won: bool) -> String:
	return STAMP_WIN if won else STAMP_MISS


func _payoff(won: bool) -> void:
	if won:
		var clean := cars.size() - tickets
		var sub := WIN_SUB_ALL if tickets == 0 else WIN_SUB_SOME % [clean, cars.size()]
		announcer.callout(WIN_TITLE, sub, WIN_TINT, true)
		ComicPopup.spawn(self, player.global_position + Vector2(0, -40), &"job", WIN_WORD)
	else:
		announcer.callout(MISS_TITLE, MISS_SUB, MISS_TINT)


func _cleanup(_won: bool) -> void:
	# The squad stays in the street as ordinary maids.
	for maid in maids:
		if is_instance_valid(maid) and not maid.is_dead:
			maid.persist = false
			if maid.enemy_state_machine.current_state is TicketState:
				maid.enemy_state_machine.change_state("ChasePlayerState")
	if player != null and player.is_dead:
		return
	for i in cars.size():
		if is_instance_valid(cars[i]):
			cars[i].drive_off(-1 if i % 2 == 0 else 1, LEAVE_DELAY + i * 0.35)
