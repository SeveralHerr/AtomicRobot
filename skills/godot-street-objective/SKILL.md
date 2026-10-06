---
name: godot-street-objective
description: Add, tune or remove a street side job (StreetObjective) in Atomic Robot - chase, defend, fetch, escort - with its goal card, callouts, rewards and no soft-lock. Use when asked for "goals other than walk right", missions, side quests, timed challenges, or "give the player a reason to go back".
---
# Street side jobs

Reference: `scripts/objectives/` - `StreetObjective` (lifecycle), `ObjectiveHud` (goal card),
`StreetObjectives` (JOBS table in main.tscn's Managers: one entry per job, `"on"` toggles it),
`SnatchChase` + `ThiefState` + `KeysProp`, `MeterDefense` + `TicketState` + `ParkedCar`.
Tests: `test_street_objectives.gd` (rules, table, door-arena placement), `test_street_jobs_live.gd`
(real player + maids). Autoplay `street_jobs.json`; metrics `objectives_won/lost`, event `objective`.

## Rules (each was a real miss)
- Place a job OUTSIDE every door arena (mouth +- arena_half_width); the test derives doors from
  main.tscn. A trigger inside an arena springs the job on a player leaving a door fight, and two
  announcers' banners overlap.
- Start only inside START_WINDOW past the mark: teleporting scenarios (and debug starts) otherwise
  met surprise jobs, and a defense "won" because its maids were purged for distance.
- Job actors set `persist = true` (Enemy.is_too_far purge) and are handed back on end.
- Never push Globals events for a job: `event(true)` slows the player to 1/3 for 1.5 s.
- Maids walking past each other on one lane shove (EnemySeparation): route travel on a road lane
  and step to the walkway only at the work spot.
- Payoff bursts hide the live ComicPopup, so a world word under a burst never shows; numbers in a
  burst subtitle are unreadable - put points on the card stamp.
- Job stripes sit at EncounterAnnouncer.JOB_STRIPE_Y (0.44): at the door's 0.36 they covered the card.
- A bot-unwinnable chase is a balance smell: size the gap (getaway sprint) and speed so steady
  walking closes it in ~half the clock; the juke-then-tire rule keeps lane matching meaningful.
- A running job is a scripted fight for AmbientTraffic (`StreetObjective.RUNNING` group,
  `AmbientTraffic.scripted_fight`): parked cars push lane-1 traffic onto the squad's lane.
- A miss must not cost health: a missed squad walks off and fades instead of mobbing.
- Card pips map one to one to targets in street order and show live progress; a centred
  stamp hid them as the result read (stamp sits lower right). A clock that is only a
  backstop stays off the card (`show_time = false`).
- Props that leave (cars) go AWAY from the player and must end off screen; a fixed
  direction drove through the fight and vanished mid-screen.
- ComicPopup clamps into view: an off-screen event's word at the screen edge is a cue,
  not a clipping bug.
- New maid spawns draw from the global RNG and shift every later seeded roll: rerun
  full_run_mortal; a won job's heart refunds the health its fights cost before the boss.

## Validate
Four windowed scenarios (win/miss per job, `snap_every 0.25-0.5`) + contact sheets per round,
one `--resolution 1688x780` round, one `crt on` round, one mortal seed sweep (job win
rate, hits taken inside it); GIFs cut from `--record` mp4s (trim/concat,
fps 12, width 440-460, 80 colours keeps them < 4 MB). Re-extract a suspect frame at full size:
adjacent tiles faked two overlapping parked cars.
