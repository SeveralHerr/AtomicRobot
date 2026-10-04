---
name: godot-micro-cutscene
description: Add or tune a short in-level cut scene in Atomic Robot (or any Godot 4 side-scroller) — camera pull-back to show off level art, letterbox, comic caption, landmark triggers, skip — without breaking tests, autoplay or the fight. Use when asked for cut scenes, establishing shots, "show off the art", "zoom out at X", intros, or a landmark reveal.
---
# Micro cut scenes

Reference: `scripts/cutscene/` — `CutsceneShots` (data table + pure framing/trigger
funcs), `MicroCutscene` (director), `CaptionCard` (comic caption box),
`StreetCutscenes` (node in main.tscn: opening on load + x triggers). Tests:
`test_cutscene_shots.gd`, `test_micro_cutscene.gd`; autoplay `cutscenes.json`
(`cutscenes == 3` metric).

## Find the art first
- Locate landmarks headless: instantiate the level in a `--script` SceneTree and print
  `global_position` + texture size of the Sprite2Ds by texture path.
- Frame them before writing code: a paused capture script moves a bare Camera2D
  through candidate (pos, zoom) pairs and saves PNGs -> one contact sheet. Pick zooms
  from that, not from maths. (Play zoom 2.5 shows 512x320 world px.)
- A shot must never look under the road: centre.y <= limit_bottom - 400/zoom. Pinned by
  `test_every_shot_stays_above_the_road` (caught 2 shots off by 2-6 px).

## Rules (each was a real miss)
- Off unless the run came through the front end (`StreetCutscenes.enabled` set by the
  controls splash): tests/sandboxes/autoplay loading main.tscn directly are untouched.
  Once per session (`seen`), so a restart doesn't replay.
- Freeze the fight, not the tree: player processes off + god + IdleState, enemies
  `PROCESS_MODE_DISABLED` (restore their old mode), `PowerupSystem.hold`, spawner
  skips while `MicroCutscene.playing`. Leaves/cars/water keep moving. Pause menu still
  pauses it; the pause key never skips.
- Street trigger = at mark (with a give-up window) + street QUIET for a beat: no live
  enemy within radius AND `Globals.event_active()` false (a door between waves has
  nobody alive but its next wave is coming). Then `call_group(BossBanner.GROUP,
  "clear_title")` so a STREET CLEAR! still up leaves as the camera pulls back. Waiting
  out its full hold was too long: the next door was 3 s' walk away.
- Opening under `Transition`'s paused fade: tweens don't run, so set the first frame
  (HUD alpha 0, bars in) directly; test it through `Transition.fade_through`.
- Hand-back: glide to `CutsceneShots.play_center(player)` (clamped like the play
  camera), then `make_current()` + `force_update_scroll()` + `reset_smoothing()` — a
  non-current camera doesn't scroll, so after a teleport it slid in from the old spot.
- Skipping: HOLD, not press (user: "too easy to skip" — mashing through the front end
  ate the story). Poll actions (touch buttons use `Input.action_press`), arm only
  after every skip button was up once, drain on release; prompt appears on a press.
- Bodies: hold each one only once landed (`Player.is_settled()` = grounded AND on its
  spawn lane; enemies `is_on_floor()`, cap SETTLE_MAX). A level-load opening froze
  the player and roof maid at spawn height ("floating"), then the player dropped 48 px
  onto the road lane right after hand-back. `lanes_active()` is false on the landing
  frame — don't use it to mean "this scene has lanes".
- Story/intro text belongs IN the opening as a caption sequence (`captions` list),
  each title readable until the next caption (`caption_until`); a "pops" cue drops a
  ComicPopup word in the world (TICKET! on the car).
- Caption z-order: add/raise it AFTER the letterbox bars; lightning flash goes UNDER
  the bars (`move_child(..., 0)`).
- Readability: derive time-to-title from typing (`CaptionCard.lands_after`) and test
  `title lands + READ_S <= duration`; start typing during the box pop.

- Tests: a level added with `root.add_child` is NOT `current_scene`, so
  `Lanes.scene_has_lanes` is false and lane behaviour (spawn-lane snap) never runs —
  set `current_scene = level`, or a lane bug passes every test (3 mutants did).

## Autoplay
Runner waits while `MicroCutscene.playing` (no new presses = no skip), logs `cutscene`
events, and the recorder doesn't count the freeze as stuck. Skip-guard tests must wait
past the skip glide (`SKIP_RETURN_TIME`), or "still playing" passes on a skipped scene.

## Validation
`python tools/autoplay.py x.json --window` with `snap_every 0.25`, then
`python tools/contact_sheet.py <run> <t_from> <t_to>` (MCP `contact_sheet`) per scene;
one `--resolution 1688x780` round; final pass on a `--record` natural run, cut with
ffmpeg `trim`/`concat` into a reel.
