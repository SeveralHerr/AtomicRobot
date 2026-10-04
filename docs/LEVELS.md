# Atomic Robot — Levels, Scenes & Tilemaps

How level geometry is authored and how to inspect/edit it. See
[ARCHITECTURE.md](ARCHITECTURE.md) for scene flow and code structure.

> **Inspect a level without the editor:**
> `godot --headless --path . --script res://tools/dump_level.gd -- --scene res://scenes/main.tscn`
> dumps tilemap cells, collision bodies, spawn markers, triggers, and camera limits as JSON
> (see "Tooling" below).

## The playable scenes

- **`scenes/main.tscn`** — THE level (~1200 lines, root `Main: Node2D`, no root script).
- **`scenes/boss_room.tscn`** — boss fight room (root script `boss_room.gd`).
- `startscreen.tscn`, `character_select.tscn`, `controls_splash.tscn` — Control-based menus.
- `final_boss.tscn` — the boss **actor**, instanced by boss_room.gd.

## main.tscn high-level tree

```
Main (Node2D)
├─ UI (CanvasLayer layer=2)            health, notifications, fades, game-over
├─ Sprite2D                            sky backdrop
├─ WaterHandler (water.gd)             water + splash/audio Area2Ds
├─ Parallax2DBackground / Parallax2D / Parallax2D2 / ForegroundParallaxLayer
├─ SceneItemsBackground (Node2D)       ← BULK OF THE LEVEL
│  ├─ BuildingGroup1..4                buildings, props, platforms, enemies, meters, triggers
│  ├─ TileMapLayer (line ~951)         ← PRIMARY GROUND (tiles/tileset.tres), z=1, pos (-1875,0)
│  ├─ RightBoundary / LeftBoundary     end-wall StaticBodies (layer 64 "wall")
│  └─ AtomicRobotBuildingGroup         instance of atomic_robot_building_group.tscn
├─ SceneItems                          streetlights, intersections
├─ EnemyManager (enemy_manager.gd)     timed random enemy waves
├─ LeafManager                         leaf physics
├─ Player (instance, top_level=true, pos (-292,-21))
├─ TileMapLayer (hidden)               decorative/disabled layer
└─ UnderWorldKillBox (Area2D)          fall-death volume → player.death()
```

## Ground geometry — three techniques, mixed

1. **TileMapLayer tiles (primary ground).** `SceneItemsBackground/TileMapLayer`
   (main.tscn ~line 951) with `tile_set = res://tiles/tileset.tres`. Collision comes
   from the **TileSet's physics layers**, not separate colliders:
   - `physics_layer_0` → collision_layer **2 (Ground)**
   - `physics_layer_1` → collision_layer **32 (Platforms)**, some tiles `one_way = true`
   - per-tile polygons are mostly full 32x32 boxes.
   Smaller overlay layers nested beneath, plus one under `BuildingGroup1`.
2. **StaticBody2D + CollisionShape2D** for props/walls: crates, trashcans, buildings,
   and the level-edge walls (`RightBoundary`/`LeftBoundary`, layer 64 "wall", mask 31).
   Boss room ground/walls are entirely StaticBody2D (layer 2 Ground) — no tiles there.
3. **One-way platforms**: instances of `scenes/platform.tscn` — Sprite2D +
   StaticBody2D(layer 32) + `one_way_collision = true` RectangleShape (60x6).

## Tilesets (`tiles/`)

- **`tiles/tileset.tres`** — primary gameplay TileSet. `tile_size = 32x32`,
  15 atlas sources built from `res://images/new/*.png` (Street, Building, Sewer,
  Scaffold, fence, beam...). This file also owns the collision polygons (above).
- **`tiles/asset_tiles.tres`** — secondary TileSet (scaffolding_foreground.png) holding
  4 reusable `TileMapPattern` stamps + terrain sets.
- `tiles/*.png` are mostly raw source sheets (MooseponD city pack); the in-use textures
  live in `images/new/`.

### Editing tile layouts

`tile_map_data` in .tscn is **packed binary base64** (~46 KB in main.tscn) — never
hand-edit it. Options:
- Godot editor TileMap panel (normal workflow).
- Headless tool script using `TileMapLayer.set_cell()` / `set_pattern()` then
  `ResourceSaver.save()` on a packed scene.
- Read/verify with `tools/dump_level.gd` (headless) or the runtime devtools verb
  `cmd dump_tilemap` (see CLAUDE.md).

## Object placement

- **Authored**: instances with explicit `position` under `SceneItemsBackground/BuildingGroup1..4`
  — `meter.tscn` (parking meters register into `Globals.meters`), `meter_maid_platform.tscn`,
  `meter_maid_melee.tscn`, `atomic_heart_pickup.tscn`, mailbox, cars, crates, trees, lamps.
- **Runtime**: `EnemySpawner.spawn_enemy()` places maids at
  `Vector2(player.x ± viewport/3, player.y)` (`enemy_spawner.gd:25`), driven by
  `EnemyManager` (3-30 s random timer, only when `player.is_near_ground()`, paused
  during events).
- **Triggers**: `EnemyEvent` Area2Ds (`enemy_event.gd`) fire scripted waves;
  `BuildingGroup4/Enter` (`final_boss_enter.gd`) changes scene to boss_room;
  `building_door_encounter.tscn` (`BuildingDoorEncounter`) is the TMNT-style
  burst — a squad pours out of a doorway across the lanes and optionally locks the
  player in with barriers + camera limits until the street is clear. The squad
  (`enemy_count`) comes out in 1–3 `waves`; each next wave waits for the current
  one to be fully down, then rumbles and re-bursts the door with a comic
  `WAVE n/N` callout (`EncounterAnnouncer`, reusing `BossBanner`) and ends on
  `STREET CLEAR!` (squad only; ambient maids may remain). Seven instances ramp along the street (x / waves x squad):
  389 1x3 · 2361 2x4 · 4721 2x4 · 5492 2x4 · 6080 2x5 · 6949 3x6 · 7775 3x6.
  `test_street_waves_*` pins the ramp and "no 1-maid wave"; `door_waves` autoplay
  plays one. Drive it headless with `cmd list_encounters` / `cmd trigger_encounter`.

> **Spawning gotcha:** `EnemySpawner.spawn_enemy*()` applies `global_position` while
> the enemy is still an orphan (its `add_child` is deferred), so the parent's
> transform is added afterwards. Always pass `get_tree().current_scene` as the
> parent — passing a `BuildingGroup` (at ~(1875,-1)) displaces spawns by thousands
> of px. This was a live bug in `enemy_event.gd` and `window_event_building.gd`.

## Visual layering — manual z_index only

**No `y_sort_enabled` anywhere in the project.** Conventions:
far background parallax `z_index=-1` (boss bg `-4`) · ground TileMapLayers & most props `1`
· water/cars/hero accents `2` · UI on CanvasLayer `layer=2`. Godot 4 `Parallax2D` nodes
(not legacy ParallaxBackground) with `scroll_scale`/`repeat_size`.

## Boundaries, death, camera

- **Fall death**: `UnderWorldKillBox` (main.tscn, `under_world_kill_box.gd`) —
  `body_entered` → Player → `death()`, anything else → `queue_free()`.
  Also `fall_death_collision.gd` (`take_damage(3)`).
- **Horizontal bounds**: physical wall StaticBodies (LeftBoundary/RightBoundary),
  NOT camera limits.
- **Camera**: child of Player (`player.tscn:213-218`), zoom 2.5, `limit_bottom=30` only.
  boss_room.tscn overrides limits on its Player instance (`limit_left=-465,
  limit_right=475, limit_bottom=0`).

## Tooling

- `tools/dump_level.gd` — headless JSON dump of any scene: TileMapLayer used cells /
  used_rect / ground-surface profile, collision shapes in world coords, markers,
  Area2D triggers, camera limits, instanced sub-scenes with positions.
- `tools/fix_uids.gd` — rewrites stale `uid://` refs after reimports (run if lint
  reports uid mismatches).
- Runtime: `python3 tools/devtools.py cmd dump_tilemap` / `cmd level_info` /
  `cmd player_state` etc. — see CLAUDE.md cheat-sheet and `list-commands`.
