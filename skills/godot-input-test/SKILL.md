---
name: godot-input-test
description: Write headless Godot 4 unit tests that drive a UI or player feature with injected pad/key/stick/touch input, and mutation-check them. Use when testing menus, initials/name entry, focus navigation, or anything that polls Input.is_action_*.
---
Runner: `godot --headless --path . --script res://tools/run_tests.gd -- --filter <method-substring>`.

## Injecting input (the gotchas that cost retries)
- **Inject at frame start.** `await process_frame` resumes BEFORE nodes' `_process`, but
  `await create_timer(t).timeout` resumes AFTER it. A press injected right after a timer
  and released one frame later is never seen by polling code. Helper:
  ```gdscript
  func _pad(b: JoyButton) -> void:
      await _frames(1)                       # align to frame start
      for pressed in [true, false]:
          var ev := InputEventJoypadButton.new(); ev.button_index = b; ev.pressed = pressed
          Input.parse_input_event(ev); Input.flush_buffered_events()
          await _frames(1)
  ```
- `Input.action_press` from a timer/`create_timer` resume lands AFTER that frame's
  `_process`, so `is_action_just_pressed` never sees it: `await process_frame` first.
- **Polling code must check `is_action_just_pressed` first**, then `is_action_pressed` for
  hold-repeat — a tap pressed+released between frames never reads as pressed.
  Test it: parse press AND release before one `await _frames(2)`.
- Analogue stick: send 4-5 `InputEventJoypadMotion` with rising values; assert ONE step.
- This project binds W/A/S/D to `ui_up/left/down/right`: a text/initials field must
  mute direction polling after a typed letter (set the flag in `_input`, which runs
  before `_process` in the same frame).
- Key events need `keycode`, `physical_keycode` AND `unicode` set to behave like typing.
- Raw `InputEventScreenTouch` is ALSO delivered as an emulated left click (Godot default
  `emulate_mouse_from_touch`), so a touch branch's mutant survives: call
  `Input.set_emulate_mouse_from_touch(false)` around the touch test (test_title_splash.gd).
- Touch on GUI: NEVER fake it with `button.pressed.emit()` — that hid a select screen
  whose "tap again" never worked (Button fires `pressed` on RELEASE, ~6 frames after the
  press moved focus). Headless window is 0x0, so `Input.parse_input_event` touches never
  hit the GUI either: `root.push_input(ev, true)` a ScreenTouch AND the emulated
  MouseButton (device `InputEvent.DEVICE_ID_EMULATION`) at the control's
  `get_global_transform_with_canvas() * size/2`, hold 1/6/30 frames
  (`_tap` in test_character_select.gd). Assert sizes vs `ComicStyle.TOUCH`.
- Autoload state (ScoreSystem): swap its `save_path` in `setup()`, restore + `reload()` in
  `teardown()`, never write to the player's real `user://` file.
- A level loaded with `root.add_child()` is NOT `current_scene`; set autoload fields
  (e.g. `current_scene_path`) by hand.

- Recording a GIF with injected input: call `Input.flush_buffered_events()` after every
  `parse_input_event`, or a release lands a frame late and a held stick overshoots.
- **Parent fixtures under one world Node2D** freed in teardown, not straight on root:
  hits spawn sparks/popups/shots as SIBLINGS of the target, and leftovers on root broke
  `test_end_card`'s child-count check (order-dependent failure).
- "Bug seen in a screenshot" in combat: before fixing, add a temporary `print` of the
  hit geometry (dx * facing, lanes) in the hit loop and run autoplay; 0 negatives in
  ~220 real hits proved melee-hits-behind was not real (test_melee_facing.gd).
- **Assert the precondition** before asserting a state change ("player live before the
  clear"): `boss_room.gd` already freezes the player, so "frozen after" passed vacuously
  until a mutant survived.

## UI layout gotchas met here
- A Container resets its children's rotation/scale on every layout: tilt a card by
  putting it in a plain `Control` whose `custom_minimum_size` tracks the card's size.
- A big Komika letter in a PanelContainer stretches it tall (huge line height): put the
  Label in a zero-min `Control` with full-rect anchors to keep a square plate.
- Touch controls that hit-test in `_input` (MobileUI) eat taps under an overlay: hide
  them AND `set_process_input(false)` when a full-screen card shows.

## Mutation check (prove the tests bite)
Write `$TEMP/mut.py` with a list of `(file, original, mutant, filter)`; for each: replace,
run the runner with `--filter`, restore in `finally`, print KILLED/SURVIVED. Every
survivor → add a test (this found the missing same-frame-tap and mash-guard-on-keys tests).

## Screenshots of the result
Use the repo skill `godot-headful-screenshot`; add `--resolution 1688x780` for a
landscape-phone check and paste shots into one PIL contact sheet to review several at once.
