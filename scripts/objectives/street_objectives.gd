extends Node2D
class_name StreetObjectives

## The street's side jobs (StreetObjective), placed from the table below — so a job is
## added, moved or dropped here, not by hand in main.tscn. Each entry is one job: flip
## its "on" to false (or delete it) to take it out of the game.
##
## Placement: each job owns a stretch of street OUTSIDE every door's arena (pinned by
## test_job_no_job_triggers_inside_a_door_arena) — door arenas cover 69-709, 2041-2681,
## 4487-5127, 5172-5812, 5760-6400, 6629-7269 and 7455-8095.
## - MeterDefense (TICKET SWEEP!): the arch, between the x 6080 hedge door (arena to
##   6400) and the x 6949 hedge door (trigger from ~6839) — the bare stretch the arch
##   cut scene (trigger 6250) pans over. The cars are parked before the reveal, the job
##   waits for the cut scene, and the next door holds while the job has the street
##   (StreetObjective.BUSY). Meters: BuildingGroup3/ArchMeter1-3, one behind each car.

const JOBS := [
	{"on": true, "script": preload("res://scripts/objectives/meter_defense.gd"),
		"props": {"trigger_x": 6410.0, "car_xs": [6460.0, 6595.0, 6730.0], "after_cutscene": "arch"}},
]

## Off for every job (a test or scenario that must not meet one).
static var enabled := true

var jobs: Array[StreetObjective] = []


func _ready() -> void:
	if not enabled:
		return
	for entry: Dictionary in JOBS:
		if not entry["on"]:
			continue
		var job: StreetObjective = entry["script"].new()
		for key: String in entry["props"]:
			var value: Variant = entry["props"][key]
			if value is Array:
				var typed: Array[float] = []
				typed.assign(value)
				value = typed
			job.set(key, value)
		add_child(job)
		jobs.append(job)
