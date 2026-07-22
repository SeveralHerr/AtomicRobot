# Multi-Lane Movement Refactor — Playbook

Goal: TMNT-arcade-style depth lanes — the player (and enemies) can move "up/down"
between 2-4 parallel depth lanes in addition to left/right, jumping, and attacking.
This doc catalogues every place the current code assumes a single ground plane,
so the refactor can be planned and reviewed against it. Line numbers are as of
commit `eceb471` (2026-07) — re-verify before editing.

## STATUS — increment 1 SHIPPED (2026-07-21)

The core system is implemented and runtime-verified on the street level:

- **`scripts/lane_system.gd`** (`class_name Lanes`): 3 lanes, 16px spacing, front
  lane (2) = original ground with real collision, lanes 1/0 up-screen on virtual
  floors. All math static + unit-tested (`test/unit/test_lane_system.gd`).
- **Player** (`Player.gd`): `current_lane`, baseline capture from the physical floor,
  virtual-floor snap, `is_grounded()` replacing `is_on_floor()` across all states,
  tap-W/S = lane step (polled edges, works with injected input), hold-S ≥0.25s =
  crouch (CrouchState exit is now polled too). Jumping works within any lane.
- **Enemies** (`enemy.gd`): `lane` + same virtual-floor logic; chase states step one
  lane toward the player (0.7s cooldown); `can_attack()` requires same lane;
  melee attack and all projectiles (robot/flipflop/coin) are lane-tagged and only
  hit same-lane targets. Spawner spawns on the player's current lane.
- **Draw order**: `z_index = 1 + lane` on lane entities (front draws on top).
- Scene-gated via `Lanes.LANE_SCENES` — main.tscn only; boss room single-plane.
- Also fixed here: KnockbackState enter/exit naming bug; DevTools input injection
  now dispatches real InputEvents (event-driven handlers work under automation).

### Known v1 limitations / next increments
- Props (trashcans, meters, cars) don't occlude back-lane entities correctly yet
  (props are z=1; proper fix is y-sort or lane-aware prop z). Street art is not
  visually widened for depth; lanes play on the existing ground strip.
- Back-lane jumps can land on real one-way platforms above (emergent, physically
  consistent; revisit if it feels wrong).
- Platform/window meter maids are lane-locked to FRONT; boss room untouched.
- Hand-placed street enemies default to FRONT lane; no authored lane assignments.
- `nearest_meter` / FindMeter is not lane-aware (maids may refill cross-lane).

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
