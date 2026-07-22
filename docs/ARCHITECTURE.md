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
- `scripts/game_over_container.gd:14`, `win_container.gd:13`, `restart_ui.gd:14`

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
| `DevTools` | `addons/godot_selftest/dev_tools.gd` | Self-test harness bridge (see CLAUDE.md) |

## Global signals (`globals.gd:3-11`)

| Signal | Emitted from | Listened by |
|---|---|---|
| `player_death` | `states/dead_state.gd:9`, `states/boss_dead_state.gd:9` | `enemy.gd:64` (freeze), `boss_room.gd:28`, `game_over_container.gd:16`, `restart_ui.gd:9` |
| `meter_maid_death` | `enemy.gd:150` | (kill counting) |
| `boss_death` | `city_council_boss.gd:21` | `win_container.gd:15` |
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
| Idle | `velocity.x = 0` | axis→Walk/Run, `ui_accept`→Jump, `Attack`, `ui_down`→Crouch |
| Walk / Run | `velocity.x = move_toward(vx, dir*speed, ACCEL*dt)` | Run = Shift held |
| Jump | `velocity.y = -450` on enter; air control ×0.6; release halves vy | |
| Fall | air control; squash tween on land | entered automatically from `_physics_process` |
| Attack | `velocity = ZERO`; per-character projectile or Area2D overlap hits | frame timing from `Globals.get_current_character_attack_frame()` |
| Crouch | swaps body collision shape; `ui_down` held | |
| Climb | **DEAD CODE** — registered but never entered; only vertical-movement code in repo | natural seed for lane movement |
| Knockback | decays `velocity.x` | **BUG**: methods named `enter`/`exit` instead of `enter_state`/`exit_state` → timer never init, exits almost immediately |
| Dead | zero velocity, emits `player_death` | terminal |

### Input actions (`project.godot` [input])

`ui_left`/`ui_right` (A/D, arrows, dpad, stick), `ui_up` (W/up — **only used by dead
ClimbState, effectively free**), `ui_down` (S/down — crouch in idle/walk/run/fall/attack),
`ui_accept` (jump), `Attack` (F), `Interact` (E), `Run` (Shift).

## Enemies

Base `scripts/enemy.gd` (`class_name Enemy extends CharacterBody2D`); per-enemy
`EnemyStateMachine` (`enemy_state_machine.gd`, blocks transitions after death).
Gravity 300 in `_apply_gravity` (L139). **Movement is horizontal-only**:
`move_towards_target()` (L99-105) normalizes 2D direction but sets only `velocity.x`.

Variants (each registers its own states in `_ready`):
- **MeterMaid** (`meter_maid.gd`): ranged coin thrower; Chase/Attack/FindMeter/Dead. Coins are ammo — refills at parking meters (`FindMeterState`, `Globals.nearest_meter`).
- **MeterMaidMelee** (`meter_maid_melee.gd`): speed 150, cooldown 1; Area2D overlap melee.
- **PlatformMeterMaid** (`meter_maid_platform_patrol.gd`): edge-aware patrol via down raycasts.
- **MeterMaidWindow** (`meter_maid_window.gd`): stationary, activates on line-of-sight.
- **FinalBoss** (`city_council_boss.gd`): briefcase spirals; emits `boss_death`.

Spawning: hand-placed instances in main.tscn + `EnemyManager` (`enemy_manager.gd`,
timed random waves, gated by `player.is_near_ground()`) + `EnemyEvent` Area2D triggers
(`enemy_event.gd`) + `window_event_building.gd` + `boss_room.gd`.

Projectiles: `robot_bullet.gd`/`flipflop_bullet.gd` (player; pure `position.x += dir*10`),
`coin_bullet.gd` (RigidBody2D gravity arc at player), `briefcase_bullet.gd` (homing spiral).

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

## Known quirks

- KnockbackState method-name bug (above) — knockback ends almost instantly.
- `states/static_attack_state.gd` references members that don't exist on `Enemy` — legacy/dead.
- `Player.JUMP_VELOCITY` and `FRICTION` unused; `update_facing_direction()` unused.
- README.md tracks user-facing bugs (highlighting, collision, health).
