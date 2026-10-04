# Atomic Robot — Architecture Reference

Godot **4.7** (GL Compatibility), viewport 1280x800 canvas-items stretch.
2D side-scrolling beat-em-up. This doc is the code-level map; see also
[LEVELS.md](LEVELS.md) (scenes/tilemaps) and [LANE_REFACTOR.md](LANE_REFACTOR.md)
(planned multi-lane movement).

## Scene flow

Linear scene-swap flow via `get_tree().change_scene_to_*`; no central level manager.

```
startscreen.tscn ──any key/click──> character_select.tscn ──pick──> main.tscn (or story.tscn ──> main.tscn)
main.tscn ──Enter trigger (final_boss_enter.gd)──> boss_room.tscn
game over / win ──> character_select.tscn        restart ──> startscreen.tscn
```

- `project.godot:18` main scene = `scenes/startscreen.tscn`
- `scripts/startscreen.gd:12` → character select
- `scripts/character_slot.gd:34-39` sets `Globals.selected_character`, → `main.tscn` / `story.tscn`
- `scripts/final_boss_enter.gd` — Area2D on `SceneItemsBackground/BuildingGroup4/Enter` in main.tscn → boss room
- `scripts/ui/end_card.gd` — the one end-of-run screen (`UI/EndCard` in both levels): RESTART → character select

`final_boss.tscn` is the **boss actor** (CharacterBody2D), not a room; the room is `boss_room.tscn`.

## Autoload singletons (`project.godot` [autoload])

| Autoload | File | Role |
|---|---|---|
| `Globals` | `scripts/autoload/globals.gd` | Game state, signals, `character_dict` (6 chars), `meters`, kill counts, `destroyed_nodes`, `nearest_meter()`, `debug_start_game()` (DevTools entry hook) |
| `Utils` | `scripts/autoload/utils.gd` | Static FX + projectile factories: `throw_coin*`, `throw_briefcase*`, `apply_hit_pause` (Engine.time_scale), `shake_node2d` |
| `ChatBubble` | `scripts/autoload/chat_bubble.gd` | `create(parent, text)` — bubble above node, auto-free 2s |
| `ScreenShake` | `scripts/autoload/screenshake.gd` | `apply_shake(strength, duration)` via `player.camera_2d.offset` |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | Plays looping music; minimal API |
| `EnemySpawner` | `scripts/autoload/enemy_spawner.gd` | `spawn_enemy(...)` — random maid/melee at `Vector2(spawn_x, player.position.y)` (line 25) |
| `LeafSystem` | `scripts/autoload/leaf_system.gd` | Bridges to scene `LeafManager` (gusts, sword-swing leaves) |
| `Transition` | `scripts/autoload/transition.gd` | The one fader: `change_scene_to_file/_packed(x, sting)` — 0.25s out, swap, 0.3s in, tree paused (no input) mid-fade, re-entrant requests dropped, resets `Engine.time_scale`. Every player-facing scene change goes through it (`test_transition.gd` greps for direct callers); `debug_start_game` stays instant |

## Global signals (`globals.gd:3-11`)

| Signal | Emitted from | Listened by |
|---|---|---|
| `player_death` | `states/dead_state.gd:9`, `states/boss_dead_state.gd:9` | `enemy.gd:64` (freeze), `boss_room.gd:28`, `ui/end_card.gd` (plays `ui/death_beat.gd` — 0.35x slow-mo 0.6s real, grey-out 0.45s — then the card; the signal itself is not delayed), `score_ui.gd` (hides HUD) |
| `meter_maid_death` | `enemy.gd:150` | (kill counting) |
| `boss_death` | `city_council_boss.gd:21` | `ui/end_card.gd` (card), `score_ui.gd` (hides HUD) |
| `boss_fight(status)` | boss room | `audio.gd:8` |
| `event(status)` | `enemy_event.gd:47,56` | `enemy_manager.gd:20`, `Player.gd:113`, `notificataion_container.gd:7` |
| `unlocked(name, desc)` | unlock logic | `notification.gd:11` |
| `newspaper(status)` | story beats | `news_paper_notification_container.gd:6` |
| `gust(position, range)` | `states/attack_state.gd:16` | `leaf_manager.gd:44` |

Plus per-node `player.player_health_updated` → `health_container.gd:13`.

## Player (`scripts/Player.gd`, `scenes/player.tscn`)

`CharacterBody2D`, `class_name Player`, group `player`. Instanced in main.tscn with
`top_level = true` at `(-292, -21)`.

- **Physics**: gravity 1200 + fall_multiplier 1.5 applied ONLY in `Player._physics_process`
  (L134-153); states never apply gravity. Auto-transitions to `FallState` when airborne
  with `velocity.y > 0`. `move_and_slide()` at end.
- **Tunables** (plain vars, L38-58): `SPEED=170` (+`boost_speed` via `get_speed()`),
  `ACCELERATION=1000`, `AIR_CONTROL=0.6`, `COYOTE_TIME=0.1`. Actual jump impulse is
  `JumpState.JUMP_VELOCITY = -450` (`Player.JUMP_VELOCITY` is dead).
- **Facing**: `_handle_direction()` (L237-251) flips whole-node `scale.x = ±1` —
  this mirrors the child Camera2D and attack Area2D too.
- **Collision**: layer 1 (Player), mask 122 (Ground+Meter+car+Platforms+wall).
  Body shape swaps normal/crouch resources (preloads at L6-7).
- **Attack hitbox**: child `Area2D` mask 652, CircleShape r≈32 at local `(48,-27)`.
- **Camera2D is a child of Player** (`player.tscn:213-218`): zoom 2.5,
  `limit_bottom=30`, smoothing. Boss room overrides limits per-instance.
- **Damage**: `receive_hit(source_position, damage)` (L170-221) → knockback away from
  source + `KnockbackState`; `take_damage` emits `player_health_updated`, `death()` at 0.
- `is_near_ground()` (L78-81) = `position.y >= -200` — gates enemy spawning.

### Player state machine (`scripts/states/`)

`StateMachine.new(player)`; states registered in `Player._ready()` (L90-102);
transitions via `player.state_machine.change_state("XxxState")`. Base contract
(`state.gd`): `enter_state / exit_state / handle_input / update / physics_update`,
each receiving `player`.

| State | Movement | Notes |
|---|---|---|
| Idle | `velocity.x = 0` | axis→Walk/Run, `ui_accept`→Jump, `Attack`, `Crouch`→Crouch |
| Walk / Run | `velocity.x = move_toward(vx, dir*speed, ACCEL*dt)` | Run = Shift held |
| Jump | `velocity.y = -450` on enter; air target = speed ×`AIR_SPEED_MULT` (1.2), accel ×0.6; release halves vy | |
| Fall | air control; squash tween on land | entered automatically from `_physics_process` |
| Attack | `velocity = ZERO`; per-character projectile or Area2D overlap hits | frame timing from `Globals.get_current_character_attack_frame()` |
| Crouch | swaps body collision shape; `Crouch` held | |
| Climb | **DEAD CODE** — registered but never entered; only vertical-movement code in repo | natural seed for lane movement |
| Knockback | decays `velocity.x` | **BUG**: methods named `enter`/`exit` instead of `enter_state`/`exit_state` → timer never init, exits almost immediately |
| Dead | zero velocity, emits `player_death` | terminal |

### Input actions (`project.godot` [input])

`ui_left`/`ui_right` (A/D, arrows, dpad, stick), `ui_up` (W/up — tap = lane step back),
`ui_down` (S/down — tap = lane step toward camera; also fed by the touch joystick),
`ui_accept` (jump; built-in default, includes joypad button 0/A), `Attack` (F, joypad
button 2/X), `Crouch` (C, joypad button 1/B; touch CrouchUI button), `Interact` (E, joypad button 0/A), `Run` (Shift, joypad button 5/R1).
`debug_menu` is keyboard-only by design (dev-only, not player-facing).

## Enemies

Base `scripts/enemy.gd` (`class_name Enemy extends CharacterBody2D`); per-enemy
`EnemyStateMachine` (`enemy_state_machine.gd`, blocks transitions after death).
Gravity 300 in `_apply_gravity` (L139). **Movement is horizontal-only**:
`move_towards_target()` (L99-105) normalizes 2D direction but sets only `velocity.x`.

Variants (each registers its own states in `_ready`):
- **MeterMaid** (`meter_maid.gd`): ranged coin thrower; Chase/Attack/FindMeter/Dead. Coins are ammo — refills at parking meters (`FindMeterState`, `Globals.nearest_meter`).
- **MeterMaidMelee** (`meter_maid_melee.gd`): speed 150, cooldown 1; Area2D overlap melee.
- **PlatformMeterMaid** (`meter_maid_platform_patrol.gd`): edge-aware patrol via down raycasts.
- **MeterMaidWindow** (`meter_maid_window.gd`): stationary; Hold/Attack/Dead. Overrides
  `_physics_process` (no gravity/move_and_slide) but **must still step the state machine**.
  Its scene includes the window frame, so it overrides `_death_blink_target()` /
  `_on_death_blink_finished()` (Enemy.die hooks): only the sprite blinks and hides, the
  smashed window stays.
- **FinalBoss** (`city_council_boss.gd`): 3 health-keyed phases (tuning table `scripts/boss/boss_rules.gd`): aimed
  briefcase throws (aim locks at the wind-up tell) -> upward fans + telegraphed ceiling drops + maid
  reinforcements -> charge (`BossDashState`). `boss_room.gd` directs the intro, waves, banners
  (`boss/boss_banner.gd`), HUD card (`boss/boss_health_bar.gd`) and finale; `Globals.boss_death` fires
  after the finale slow-mo. `Globals.boss_fight(bool)` swaps the music (AudioManager).

### Enemy state contract (important invariants)

- `EnemyStateMachine.change_state` **rejects unknown names and same-state re-entry**.
  Re-entry used to restart the attack animation every frame, so a swing could never
  reach its own release frame. States that need to repeat an action expose a re-arm
  path (`AttackPlayerState._begin_swing`) rather than re-entering themselves.
- `AttackPlayerState` is the shared swing base (melee + boss subclass it). It guards
  every deferred step with a `_generation` counter — a stale `await` from a previous
  swing resuming mid-swing was the "enemy randomly stops attacking" bug — and has a
  3s watchdog so a swing can never park the enemy permanently.
- Chase **movement is gated on distance, not the sight ray**; line of sight only gates
  *attacking* and the PatrolState fallback. The ray is one line and used to freeze
  enemies solid whenever it missed.
- `Enemy.line_of_sight.max_range` is raised to `detection_range` in `_ready`. The
  authored ray length (450) was shorter than the spawn distance (~477), so freshly
  spawned maids were out of sight range from birth.
- `Enemy.can_attack()` delegates the lane rule to `Lanes.can_engage`, which exempts
  `lane_locked` enemies (window/platform maids fire lane-agnostic coins from above).
- `is_player_in_attack_range` is recomputed from the live overlap set every physics
  tick, not latched from `body_entered`/`body_exited`.
- `Enemy._resolve_player()` re-resolves lazily; enemies must never assume the player
  existed at their `_ready`.

Spawning: hand-placed instances in main.tscn + `EnemyManager` (`enemy_manager.gd`,
timed random waves, gated by `player.is_near_ground()`) + `EnemyEvent` Area2D triggers
(`enemy_event.gd`) + `window_event_building.gd` + `boss_room.gd`.

Projectiles: `robot_bullet.gd`/`flipflop_bullet.gd` (player; pure `position.x += dir*10`),
`coin_bullet.gd` (RigidBody2D gravity arc at player); briefcases are the same script with a briefcase sprite.

## Characters (`Globals.character_dict`, `globals.gd:14-130`)

6 `CharacterConfig` entries (Cody, Ryan, Sara, Cass, Caitlyn, Robot): sprite frames,
sounds, `attack_frame`, `starting_health`, `starting_damage`, unlock flag/text.
`Globals.selected_character` (default "Ryan") is set by the character-select menu;
`Player._init/_ready` applies stats/sprites/sounds. `attack_state.gd:17,26` special-cases
Robot (bullet) and Cass (flipflop).

## Physics layers (`project.godot:93-105`)

```
1 Player(1)  2 Ground(2)  3 Enemy(4)  4 Meter(8)  5 car(16)  6 Platforms(32)
7 wall(64)   8 Leaf(128)  9 coin(256) 10 melee_enemy(512)    11 enemy_overlap(1024)
```
(bit values in parens). Player mask 122 = Ground+Meter+car+Platforms+wall.

## Enemy behaviour sandboxes (`test/scenes/`)

Nine one-scene-per-scenario harnesses for enemy AI — open any of them and press F6.
Each builds its own ground, player, props and enemies at runtime (`enemy_sandbox.gd`),
so none of them depend on main.tscn's tilemaps or level layout. `test/scenes/` is
registered with `Lanes.scene_has_lanes()`, so lane combat behaves as it does in the
street level. In-scene keys: `R` reset · `K` clear · `C` car · `Space` wave · `H` hide HUD.

`melee_cluster` · `ranged_cluster` · `mixed_cluster` · `coin_refill` · `window_maids`
· `no_line_of_sight` · `spawn_event` · `car_vs_crowd` · `platform_patrol`

They double as automated regression tests. `test/scenes/sandbox_selftest.gd` samples
every physics frame and fails on an inert enemy, a swing that never closes, or an
enemy walking backwards — coverage the synchronous unit runner structurally cannot
provide. Run them all with:

```bash
python tools/run_sandbox_selftests.py          # ~100s, exit 0 only if all pass
python tools/run_sandbox_selftests.py melee    # name-substring filter
```

## Known quirks

- KnockbackState method-name bug (above) — knockback ends almost instantly.
- `states/static_attack_state.gd` references members that don't exist on `Enemy` — legacy/dead.
- `Player.JUMP_VELOCITY` and `FRICTION` unused; `update_facing_direction()` unused.
- `Enemy.range_timer` (`RangeTimer`) is never started — dead.
- `State`/`EnemyState` extend `Node` but are never added to the tree, so every state
  object is an orphan node. A live main.tscn reports ~50 orphans as a matter of course,
  which permanently fails the harness's `orphan_max: 0` threshold.
- README.md tracks user-facing bugs (highlighting, collision, health).
