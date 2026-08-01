# Multi-Lane Movement Refactor — Playbook

Goal: TMNT-arcade-style depth lanes — the player (and enemies) can move "up/down"
between 2-4 parallel depth lanes in addition to left/right, jumping, and attacking.
This doc catalogues every place the current code assumes a single ground plane,
so the refactor can be planned and reviewed against it. Line numbers are as of
commit `eceb471` (2026-07) — re-verify before editing.

## STATUS — increment 3 SHIPPED (2026-07-23): fourth lane

`LANE_COUNT 3 → 4`, `FRONT_LANE 2 → 3`. Those two constants were the entire code
change — everything downstream (`clamp_lane`, `y_offset`, `floor_y`, `z_for`,
`_pick_spawn_lane`, `try_change_lane`, `_lane_chase`) is bounds-generic.

- **No new tile art.** Road fill (`tileset` source 5, atlas `2:1`) already runs to
  world y=127 across all 374 columns; lane-3 feet land at y=71.
- **Lane floors** (origin / feet): 0 = -20.75 / -1 · 1 = 3.25 / 23 · 2 = 27.25 / 47
  · 3 = 51.25 / 71. Lane 3 draws at **z=4** (nothing static occupies z=3 or z=4).
- **Camera** deliberately left at `limit_bottom = 96`, so lane 3 sits ~62 screen px
  off the bottom edge — tighter framing than the other lanes, accepted by design.
- **Kill box** clearance is now 134px (was 173) — still ample.
- **Cars** now pick a **random road lane per car** (1-3, never the sidewalk) and
  only hit players in that lane. Fixed `streetlight._car_road_y()`, which used the
  *relative* `Lanes.y_offset()` as an absolute world Y and so drove cars ~21px
  below the lane they belonged to.

## STATUS — increment 2 SHIPPED (2026-07-21): road lanes toward the camera

The lane geometry now matches classic TMNT: **lane 0 (GROUND_LANE) = the original
walkway line with real floor collision; the road lanes extend DOWN-SCREEN
(+24px each)** onto the road strip on virtual floors. No tiles were painted — the
road art already existed below the walk line (non-colliding stone fill), hidden by
the old camera clamp; `limit_bottom` went 30 → 64 → 96 to reveal it.

- **`scripts/lane_system.gd`** (`class_name Lanes`): `GROUND_LANE` owns physics;
  `y_offset()` is +LANE_SPACING per lane toward the camera. Unit-tested.
- **Baseline registry** — ONE walkway floor line per scene, resolved by
  `Lanes.baseline_on_root()` and cached in scene-root metadata. `main.tscn` authors it
  as a `LaneBaseline` Marker2D at Y=-1 (the street's top face); scenes without one get
  the first value a body seeds by standing on real ground, and nothing rewrites it
  afterwards. Levels stack several *colliding* TileMapLayers — raised building ledges
  at Y=-33 and Y=-65 in `main.tscn` — and all of them satisfy `is_on_floor()`, so the
  old per-body re-capture lifted the entire lane stack 62.5px (2.6 lane widths) when
  the player walked onto a ledge, and enemies spawned during that window kept the
  lifted value permanently. Enemies now READ the registry and never write to it; only
  the Player (or the authored marker) establishes it. `lane_locked` maids are exempt —
  they stand on platforms 60-240px above the street and their own floor line is what
  positions the power-up they drop. Covered by `test/unit/test_lane_baseline.gd`.
- **Collision handling**: the walkway tiles' collision strips occupy the road band,
  so road-lane bodies disable Ground(2)/Platforms(6) (player also Meter(4)) via
  `_set_ground_collision()` — off when leaving the walkway (tween start), back on
  when arriving at it (tween end). Walls/car bits stay on.
- **Player**: spawns on the walkway (lane 0); S taps toward camera, W back;
  hold-S crouches. Jump verified within road lanes.
- **Enemies**: `@export starting_lane` (hand-placed default = walkway) and
  `@export lane_locked`; lane-chase is wired into **ChasePlayerState** (the earlier
  chase_player() wiring was dead code — removed). Spawner picks a weighted random
  lane (40% player's, 60% others) and seeds baseline from the player.
- **Platform/window maids**: `lane_locked = true`; their arced coins are
  `lane_agnostic` (hit any lane). Street maids' coins are tagged with the lane they
  fly on — the **player's** lane at throw time, not the thrower's, since the shot is
  aimed at the player's actual position. Lane-stepping mid-flight still dodges.
- **FindMeter**: maids step back to the walkway before refilling at meters.
- **Cars** (streetlight event): road hazard on the road lanes only — see increment 3
  for the current per-car random lane behaviour.
- **Kill box**: ample clearance below the front lane — no change needed.
  `fall_death_collision.gd` is orphaned (attached to nothing).

### Known limitations / next increments
- **Water zone x 6209..6898** (splash volume) overlaps the road lanes — front-lane
  players can currently "walk on water" through it; decide: block lane-changes in
  that x-range, or bridge/reroute. (The death pit below only triggers via the
  walkway hole at x 6496..6592.)
- Props (trashcans, meters) don't occlude road-lane entities correctly yet
  (props z=1; proper fix is y-sort or lane-aware prop z).
- Enemy lane convergence is eager (0.7s cooldown) — everything stacks the player's
  lane fast; consider longer initial cooldown or per-enemy lane preference. With 4
  lanes the worst case is now a 3-step trip (~2.7s), and `FindMeterState` walking
  back to the walkway from lane 3 can read as an AI stall.
- `_pick_spawn_lane` keeps 40% on the player's lane; the remaining 60% now splits
  three ways (20% each) instead of two, so spawns are more thinly spread.
- Lane spacing 24px and crouch-hold 0.25s are feel parameters, untested by hand.
- Boss room intentionally single-plane. VirtualJoystick addon class name collides
  with a Godot 4.7 native class (mobile builds only, pre-existing).

## Recommended shape of the feature

- Add a **virtual depth axis**: `current_lane: int` + `LANE_Y_OFFSETS: Array[float]` on a
  shared `LaneManager` (or Globals). World Y = ground Y of lane + jump/gravity physics
  **relative to the lane's floor**, i.e. keep gravity but re-base "floor" per lane.
  Simplest robust model: each lane is its own set of collision layers
  (e.g. Ground_L0/L1/L2), and switching lanes tweens `position.y` by the lane offset
  while swapping `collision_mask` bits. Alternative (no physics-layer split): disable
  collision during a short lane-change tween and gate all combat by lane index.
- Drive **draw order from lane**: either enable `y_sort_enabled` on a common parent or
  set `z_index = base + lane`. Today there is NO y-sort anywhere; z_index is manual
  (bg -1, ground/props 1, accents 2) — lane z values must slot between those.
- Gate **all combat interactions by lane equality** (melee overlap, projectiles,
  line-of-sight, knockback).
- Input: `ui_up`/`ui_down` already exist with keyboard+gamepad bindings. `ui_up` is
  FREE (only referenced by dead ClimbState). `ui_down` currently means CROUCH in
  idle/walk/run/fall/attack — decide: tap = lane-down, hold = crouch? or move crouch
  to another key.

## Player-side touch points

| # | Where | What assumes single-plane |
|---|---|---|
| 1 | `scripts/Player.gd:134-153` `_physics_process` | Gravity + auto-FallState fire whenever airborne; lane Y-tween will fight gravity unless lane motion is flagged (e.g. `is_changing_lane`) or done via floor re-basing |
| 2 | `scripts/Player.gd` (new) | Add `current_lane`, lane-move method, lane→z_index/collision update |
| 3 | `scripts/states/climb_state.gd` | DEAD state already reading `Input.get_axis("ui_up","ui_down")` and moving velocity.y — skeleton for `LaneMoveState`; registered at `Player.gd:97` but never entered |
| 4 | `idle_state.gd:22`, `walk_state.gd:39`, `run_state.gd:21`, `fall_state.gd:54`, `attack_state.gd:62` | All hard-wire `ui_down` → CrouchState; add `ui_up`/`ui_down` → lane transitions here |
| 5 | `is_on_floor()` uses | `Player.gd:136,142,148,156,204` + every ground state — fine if lanes re-base the floor; broken if lanes are pure Y-offsets without collision |
| 6 | `scenes/platform.tscn` | `one_way_collision` assumes gravity-down; per-lane platforms need per-lane layers |
| 7 | `scripts/under_world_kill_box.gd`, `fall_death_collision.gd` | Y-triggered death volumes must not fire on a legitimate "down" lane |
| 8 | `player.tscn:213-218` Camera2D | Child of player, `limit_bottom=30`; decide if camera tracks lane Y or stays anchored (a lane change shouldn't read as camera "climbing") |
| 9 | `Player.gd:78-81` `is_near_ground()` | Hardcoded `position.y >= -200`; gates enemy spawning — must become lane-aware |
| 10 | `Player.gd:170-221` `receive_hit` | Knockback direction from raw position delta; cross-lane hits would impart bogus vertical knockback |

## Enemy/combat touch points

| # | Where | What assumes single-plane |
|---|---|---|
| 1 | `scripts/autoload/enemy_spawner.gd:25` | Spawns at `Vector2(spawn_x, player.position.y)` — must pick a lane |
| 2 | `scripts/enemy.gd:99-105` `move_towards_target` | Discards Y; enemies can never close vertical distance — needs lane-transition behavior |
| 3 | `enemy.gd:228-238` distance/detection + `find_meter_state.gd:13,36,42` | Raw Euclidean distance; player one lane away counts as "in range" — gate on same-lane first |
| 4 | `scripts/autoload/utils.gd:63-90` ranged targeting | Coin arc / briefcase target `player.enemy_attack_position`; cross-lane throws need lane-aware aim or same-lane gate |
| 5 | `robot_bullet.gd:15`, `flipflop_bullet.gd:16` | Pure `position.x += dir*10`; must carry a lane tag and only hit same-lane enemies |
| 6 | `attack_state.gd:36-52` (player melee), `attack_player_melee_state.gd:29-33` (enemy melee) | Area2D overlap only — add lane equality check (or per-lane collision layers make this free) |
| 7 | `enemy.gd:211-215` knockback | Planar direction from player position — same cross-lane issue |
| 8 | `scripts/line_of_sight.gd:12-15` | Raycast aimed at player regardless of lane |
| 9 | `globals.gd:149-159` `nearest_meter` | Pure distance; FindMeter should prefer same-lane meters |
| 10 | `enemy.gd:139-141` gravity 300 | Same floor re-basing question as the player |

## Level-side touch points

- Ground collision lives in **`tiles/tileset.tres` physics layers** (layer 2 Ground /
  32 Platforms) applied by `SceneItemsBackground/TileMapLayer` in main.tscn. Additional
  lanes need either (a) per-lane TileMapLayers with per-lane collision layers, or
  (b) one walkable band with lanes as pure Y-offsets + collision gating.
- Hand-placed enemies/meters/pickups in `main.tscn` have authored `position` Y values
  on the single ground line — each needs a lane assignment.
- `boss_room.tscn` ground is StaticBody2D — same split needed there if the boss fight
  gets lanes.
- No y-sorting exists; introducing it may change draw order of existing props that rely
  on manual z_index=1/2 — audit `main.tscn` z values when enabling.
- Physics layers 12+ are unused — free for `Ground_Lane1/2/3` etc. (`project.godot:93-105`).

## Pre-existing bugs worth fixing first

1. **KnockbackState** (`scripts/states/knockback_state.gd`): methods named `enter`/`exit`
   instead of `enter_state`/`exit_state`, so its timer never initializes and knockback
   ends after one frame. Fix before building lane knockback on top.
2. `static_attack_state.gd` references `enemy._update_sprite_direction` / `enemy.timer`
   which don't exist on `Enemy` — dead/broken legacy; delete or repair.
3. `Player.JUMP_VELOCITY`, `FRICTION`, `update_facing_direction()` are dead — remove to
   avoid confusion during the refactor.

## Verification hooks for the refactor

- `tools/dump_level.gd` prints the ground-surface profile per TileMapLayer — use it to
  derive/check lane Y positions.
- Runtime: `python3 tools/devtools.py cmd player_state` (lane/pos/state),
  `cmd teleport_player --args '{"x":..,"y":..}'`, `cmd spawn_enemy`,
  `input press/tap ui_up|ui_down`, `set-game-speed`, `wait-frames` — deterministic
  lane-change tests without a human at the keyboard.
- Add unit tests under `test/unit/` for pure lane math (lane→Y mapping, same-lane
  gating predicates) — runnable headless with no game.
