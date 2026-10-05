---
name: godot-perf-probe
description: Measure Atomic Robot frame time / hitches during a real bot playthrough and attribute spikes to what spawned that frame. Use for "fps drops", "lag", "stutter", "performance pass", or before/after a perf fix.
---
# Perf probe

`tools/perf_probe.gd` is a SceneTree `--script` that boots the main scene (autoloads,
incl. Autoplay, run normally) and writes one CSV row per frame: wall frame time, render
CPU/GPU ms, draw calls, nodes, orphans, scene, player x, `Engine.time_scale`, and the
nodes added that frame (`node_added`, by scene file or script).

```
G=<godot 4.7.1 console exe>
# uncapped: wall time per frame == true frame cost
"$G" --path . --mute --fixed-fps 60 --disable-vsync --script res://tools/perf_probe.gd \
  -- --autoplay test/autoplay/full_run_mortal.json --autoplay-out OUT --perf-out run.csv > out.txt 2>&1
# player-like: drop --fixed-fps/--disable-vsync (locks to the monitor)
python tools/perf_attrib.py run.csv 16.7   # percentiles, spikes, "spawned X -> spike rate"
```

## Measurement traps (each one cost a wrong lead, 2026-10-04)
- **Never pipe stdout to grep/less while measuring.** Every `print()` blocks on a slow
  pipe: hit frames "spiked" 33-47% piped, 0% with stdout to a file. Redirect to a file.
- `full_run.json` has `snap_every: 10` -> a 30-50 ms screenshot every 600 frames. Use a
  scenario without snaps (`full_run_mortal`) for perf.
- `Performance.TIME_PROCESS/TIME_PHYSICS_PROCESS` read per frame are stale (sticky for
  many frames) — trust wall-clock deltas, not those monitors.
- A bare SceneTree bench window can be throttled by Windows (~15 ms every frame) — compare
  against its own baseline frames before trusting it.
- Chrome tab with `visibilityState: hidden` runs 0 rAF -> no web FPS from a background tab.
- Spikes on the frame where `ts` flips 1 -> 0.01 are the hit frame (hitstop), not the freeze.
- Orphans: `Node.print_orphan_nodes()` at frame N names the leaking scripts.

A/B a suspected cause in a throwaway worktree (`skills/godot-ab-worktree`), 2 runs per
variant; compare `spikes>16.7` and the per-spawn spike rate, not one run's max.

## Web / Picade memory (Pi 5, 1 GB: ~400 MB for tab + graphics)
`python tools/web_mem_run.py <empty-profile-dir> http://127.0.0.1:PORT/index.html out.json`
(needs `pip install websocket-client`, best in a scratch venv; serve the export with
`python -m http.server`). Launches its own Chrome with background throttling off (a hidden
tab otherwise runs 0 rAF), walks title -> street with CDP keys, and logs private MB per
Chrome process type + JS heap + fps.
Baselines 2026-10-04 (PC Chrome): empty Godot 4.7 web = ~250 MB tab / ~210 MB GPU process;
Atomic Robot in play = 440-565 MB tab / ~620 MB GPU. JS heap ~= pck size + 9 MB: the
whole pck lives in RAM, so pck MB == RAM MB. Music Stream vs Sample: no change. Capping all
textures at 1024 px: pck 65->38.6 MB, tab only -30..60 MB.
Native VRAM: `Performance.RENDER_TEXTURE_MEM_USED` per scene; texture owners by walking
autoloads + script constants (an autoload preloading a big image pins it for the whole run).
