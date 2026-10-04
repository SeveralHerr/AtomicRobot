---
name: godot-rare-spawner
description: Add a rare, fair, ambient hazard/spawner to Atomic Robot (traffic, falling props, flyovers) without breaking seeded autoplay balance. Use when adding anything that "occasionally" spawns across the street level, or when a seeded mortal scenario flips after an unrelated change.
---
# Rare ambient spawner (lessons from AmbientTraffic)

1. **Own RNG, never the global stream.** One extra `randi()` at `_ready` flipped seeded
   `full_run_mortal` from a win to a street death (every later enemy roll shifts). Use a
   private `RandomNumberGenerator`; `randomize()` in play, a `static var fixed_seed` the
   autoplay runner sets (`tools/autoplay/runner.gd`). Pass it to spawned nodes (`Car.rng`).
   Test: `seed(42); expected=randi(); seed(42); spawn; randi()==expected`.
2. **Clock runs on open play only**: decrement only when allowed (no cut scene
   `MicroCutscene.playing`, no `Globals.event_active()`, player alive + lanes measured,
   nothing of the kind already active). Pausing beats "skip": no instant spawn after STREET CLEAR.
   Measured: the bot spends only ~25-40% of street time in open play — tune for that.
3. **Telegraph**: start off screen by `speed * LEAD_S`, so the lead is constant for every speed.
   Edge sign on a `CanvasLayer` (layer 3, `follow_viewport_enabled`) — world z can't beat the
   touch buttons (UI layer 2), which cover both road edges on phones. Inset >= 44 world px
   (CRT mask). Hand off when the nose reaches the sign. Free `VisibleOnScreenEnabler2D`
   before `add_child` to let the audio telegraph off screen.
4. **Street ends**: bound start AND exit by the end buildings' inner wall faces
   (L -1440, R 9170), not the boundary node positions.
5. **Fairness numbers**: `car_hits` autoplay metric + `python tools/autoplay_sweep.py --base
   test/autoplay/full_run_mortal.json --chars Ryan --seeds 1,...,24`; a single seed is a coin flip.
6. **Screens**: throwaway `--script` SceneTree must stay UNTYPED (naming project classes compiles
   them before autoloads exist -> "Identifier not found: Globals"); `load()` scripts at runtime.
   Force touch UI by `show()`-ing `UI/MobileUI` children.
