---
name: godot-aspect-fill
description: Make Atomic Robot fill any screen shape (4:3 Picade cabinet, 5:4, 16:9, landscape phone) and prove no UI moved or broke. Use when the user says black bars, "not using the whole screen", letterbox, new monitor/cabinet/phone size, or after any UI change that hard-codes 1280x800.
---
Project: base 1280x800, `stretch/mode=canvas_items`, `stretch/aspect=expand` (2026-10-10). The canvas
grows on the free axis: 1024x768 -> 1280x960, 1280x1024 -> 1280x1024, 1920x1080 -> 1422x800,
1688x780 -> ~1731x800. 16:10 must stay pixel-identical (`test_display_stretch.gd` pins both).

## Sweep (the "play it at every aspect" step)
- `python tools/aspect_sweep.py` -> `autoplay_out/aspect/sheet.png` (rows = states, cols = sizes, same
  tile height so a ragged column = drift/gap). `--crt` forces the CRT on (hides ~40px of each edge).
  `--sizes 1024x768,1688x780` for a quick round. Tour = `tools/aspect/tour.json` (title, select,
  controls, street, pause, 45 s snaps, win card). Extra states: pass your own scenario.
- Snaps are only real with `--window`; headless gets 1280x800 (`Utils.fit_headless_root`: the 64x64
  headless window would otherwise be a 1280x1280 canvas and every test/bot run a square screen).

## What broke when we flipped it (where to look first)
- Fixed-size layouts: `const DESIGN/VIEW := Vector2(1280,800)` (character select, cut-scene framing),
  hard `position.x = 1196` (skip prompt), `offset_top = 335` (touch MENU), fold drop 640px.
  Fix: centred 1280x800 frame (`scripts/ui/select/backdrop.gd`) or edge insets + `size_changed`.
- Non-uniform cover: backdrops stretched to the rect go oval -> scale evenly to cover (`scripts/sway.gd`).
- Shader grids: CRT `resolution` must scale per axis with the rect (`CRTOverlay.grid_for`) or cells smear.
- Camera: taller view shows above the sky -> `limit_top` (street -808, boss -504). Arena narrower than
  the view: Godot centres, so aim helpers must centre too (`CameraLimitBlend.view_left`).
- Spawns "off screen" from viewport/3 or a fixed px: measure from the LIVE view edge
  (`EnemySpawner`, boss `maid_reach`) or wide screens pop enemies in / push them past detect range.
- Contact-sheet tiles lie about centring (lopsided logo art read as an off-centre pause panel):
  log rects numerically before "fixing".

## Tests
- Set `get_tree().root.size = Vector2i(w, h)`, assert from `get_visible_rect()`, restore. Loop all 5
  sizes and include 1280x800 with the OLD numbers. Examples: `test_menu_aspect.gd`, `test_hud_aspect.gd`,
  `test_story_aspect.gd`, `test_world_aspect.gd`.
- Prove-fail by copying the file aside + `git checkout --` (never `git stash` across worktrees).
