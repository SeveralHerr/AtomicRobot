extends Node2D
class_name StreetObjectives

## The street's side jobs (StreetObjective), placed from the table below — so a job is
## added, moved or dropped here, not by hand in main.tscn. Each entry is one job: flip
## its "on" to false (or delete it) to take it out of the game.
##
## Placement: each job owns a stretch of street OUTSIDE every door's arena (pinned by
## test_job_no_job_triggers_inside_a_door_arena) — door arenas cover 69-709, 2041-2681,
## 4487-5127, 5172-5812, 5760-6400, 6629-7269 and 7455-8095.
## - SnatchChase: the keys lie on the corner of the first intersection (1587-2027);
##   the thief flees back west past the scaffolds to the first door's breach.
## - MeterDefense: parks by the BuildingGroup1 meters (x 3069-3618), right after the
##   x 2361 door and its crates, well short of the x 4018 intersection.

const JOBS := [
	{"on": true, "script": preload("res://scripts/objectives/snatch_chase.gd"),
		"props": {"trigger_x": 1820.0, "keys_x": 1640.0, "flee_dir": -1}},
	{"on": true, "script": preload("res://scripts/objectives/meter_defense.gd"),
		"props": {"trigger_x": 2990.0, "car_xs": [3140.0, 3330.0, 3540.0]}},
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
