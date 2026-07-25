# Enemy behaviour sandboxes

One scene per scenario. **Open any `.tscn` here and press F6** — each one builds its
own ground, player, props and enemies at runtime, so nothing depends on `main.tscn`'s
tilemaps, encounters or level layout.

All the logic lives in `enemy_sandbox.gd`; the `.tscn` files are one-node wrappers
that just set the `scenario` enum. `test/scenes/` is registered with
`Lanes.scene_has_lanes()`, so lane movement, lane-gated combat and lane-agnostic
coins behave exactly as they do in the street level.

| Scene | What it exercises |
|---|---|
| `melee_cluster` | 5 melee maids closing from both sides across all 4 lanes |
| `ranged_cluster` | 5 coin throwers + a meter: throw → chase → run dry → refill |
| `mixed_cluster` | Melee in front, ranged behind, spread over the depth axis |
| `coin_refill` | Throwers that start empty, meters either side |
| `window_maids` | Lane-locked window maids: cross-lane fire, and they can be killed |
| `no_line_of_sight` | Walls block sight but not distance — enemies close, hold fire |
| `spawn_event` | Door-burst encounter + ambient `EnemySpawner` waves |
| `car_vs_crowd` | A crowd across the road lanes, a car every 3s in a random lane |
| `platform_patrol` | Ledge patrol overhead + melee pressure on the street |

**In-scene keys:** `R` reset · `K` clear enemies · `C` send a car · `Space` spawn a
wave · `H` hide the HUD.

The HUD lists every enemy's lane, facing, state, coins, health and animation live —
that readout is usually faster than watching the sprites.

## Running them as tests

`tools/run_tests.gd` is synchronous (a test method returns a `String`), so it can only
cover pure logic. Enemy AI is a multi-frame story, so the failures that actually bite
are invisible to it. `sandbox_selftest.gd` fills that gap: attached automatically when
`--sandbox-selftest` is passed, it samples every physics frame and fails the process on

- an enemy that never moves and never reaches attack range,
- a swing that holds its attack state past the watchdog,
- an enemy walking backwards while chasing,

plus per-scenario expectations (coins actually thrown, a maid actually topping up at a
meter, window maids being mortal).

```bash
python tools/run_sandbox_selftests.py            # all 9, ~100s, exit 0 only if all pass
python tools/run_sandbox_selftests.py melee      # name-substring filter
python tools/run_sandbox_selftests.py -v         # full child output

# or a single scene by hand:
godot --headless --path . res://test/scenes/mixed_cluster.tscn -- --sandbox-selftest
```

## Adding a scenario

1. Add a case to `Scenario` and to `_build_scenario()` in `enemy_sandbox.gd`.
2. Copy any `.tscn` here and bump `scenario = N` to the new enum ordinal.
3. Optionally add expectations to `_scenario_checks()` in `sandbox_selftest.gd`.
