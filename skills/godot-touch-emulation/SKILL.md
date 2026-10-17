---
name: godot-touch-emulation
description: Reason about and test what a phone tap really does in Godot 4 (emulate_mouse_from_touch on). Use when a tap/click behaves differently on mobile than on desktop or in tests - "one tap picks", "tap again never fires", hover-driven focus.
---
## The real event order for one finger tap (Godot 4.7, verified on a windowed run)
1. `Input` builds the emulated `InputEventMouseButton` (device `DEVICE_ID_EMULATION`) and
   dispatches it **before** the `InputEventScreenTouch` it came from.
2. `Viewport.push_input` runs `_update_mouse_over()` for every mouse event, buttons too,
   **before** `_input`. So `mouse_entered` (and anything wired to it, e.g. `grab_focus`)
   fires on the tap's press, before any of your `_input` sees the touch.
3. Then `_input` (emulated mouse) -> GUI -> `_unhandled_input`; then the touch event.
4. Release: emulated mouse up first (Button `pressed` fires here), then touch up.

Consequence: "what was focused when the tap began" can't be read inside the tap's own
events. Snapshot it in `_process` while no pointer is down (`character_select.gd` `_armed`).

## Testing
- Headless window is 0x0: `Input.parse_input_event` never reaches the GUI. Push into
  `root.push_input(e, true)` yourself, in ENGINE ORDER: emulated mouse first, then touch
  (`_tap` in `test/unit/test_character_select.gd`). Touch-first order kept a phone bug green.
- Prove it on a real window: Xvfb + `Input.parse_input_event(InputEventScreenTouch)` lets
  the engine do the emulation itself. Probe = SceneTree script that saves every frame;
  autoloads aren't identifiers in a `--script` SceneTree, use `root.get_node("Globals")`.
  Linux: `xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3
  --audio-driver Dummy --fixed-fps 30 --resolution 1280x800 --script probe.gd -- --out DIR`.
- Before/after: `git worktree add <scratch>/wt_head HEAD --detach`, copy `.godot/` in to skip
  the import, run the same probe on both, GIF the frames (PIL `save(..., save_all=True)`).
