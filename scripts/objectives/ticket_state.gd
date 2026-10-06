extends EnemyState
class_name TicketState

## A MeterDefense maid going after the parked cars: claim a car, walk to its curb slot
## on the walkway, write for `write_s` (the "refill" clip: head down at the meter),
## slap the ticket on, then claim the next car. No car left: she joins the fight.
##
## Getting hit is MeterDefense's business, not hers: it pulls her into ChasePlayerState
## for a grudge and sends her back here if she is left alone — a ticket she was
## writing starts over, so landing one blow buys the player time, not the car.

## Close enough to the slot to start writing (world px).
const ARRIVE_PX := 6.0
## Seconds for a lane step.
const LANE_STEP_S := 0.3
## She walks to her car along TRAVEL_LANE, out in the road in front of the parked
## cars, and steps up onto the walkway only within CURB_STEP_PX of it. On the walkway
## the squad shoved each other along (EnemySeparation works per lane): a maid already
## writing got pushed off her car by every colleague walking past, and the squad
## jammed into a knot between two cars.
const TRAVEL_LANE := 2
const CURB_STEP_PX := 40.0

## The MeterDefense she works for (claim_car / on_ticket).
var job: Node
var write_s: float = 3.5
var car: ParkedCar
var progress: float = 0.0


## The lane she should be on with `dx` still to walk to her car.
static func lane_for(dx: float) -> int:
	return Lanes.GROUND_LANE if absf(dx) <= CURB_STEP_PX else TRAVEL_LANE


func enter_state() -> void:
	progress = 0.0
	car = null
	enemy.animated_sprite_2d.play("walk")


func exit_state() -> void:
	_release()


func update(delta: float) -> void:
	if absf(enemy.knockback_velocity.x) >= 10.0:
		return
	if car == null or not is_instance_valid(car) or car.ticketed:
		_release()
		car = job.claim_car(enemy)
		if car == null:
			job.on_no_car(enemy)
			enemy.enemy_state_machine.change_state("ChasePlayerState")
			return
	var dx := car.curb_x() - enemy.global_position.x
	var want := lane_for(dx)
	if enemy.lane != want and not enemy.is_changing_lane:
		enemy._start_lane_change(want, LANE_STEP_S)
	if absf(dx) > ARRIVE_PX:
		enemy.velocity.x = signf(dx) * minf(enemy.move_speed, absf(dx) * 30.0)
		enemy.face_towards(car.curb_x())
		enemy.animated_sprite_2d.play("walk")
		return
	enemy.velocity.x = 0.0
	if enemy.is_changing_lane:
		return
	if enemy.animated_sprite_2d.animation != "refill":
		enemy.animated_sprite_2d.play("refill")
	progress += delta / maxf(write_s, 0.01)
	car.progress = progress
	if progress >= 1.0:
		var done := car
		_release()
		car = null
		progress = 0.0
		job.on_ticket(done)


func _release() -> void:
	if car != null and is_instance_valid(car):
		car.progress = 0.0
		if car.claimed_by == enemy:
			car.claimed_by = null
