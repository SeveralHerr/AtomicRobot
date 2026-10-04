---
name: godot-modal-reader
description: Make an in-game "read this" pop-up (newspaper, note, sign, letter) modal in Atomic Robot or any Godot 4 game - pause the tree, big centred card, CRT tune-in, fold on a fresh press - without soft-locking autoplay or the pause menu. Use when text is unreadable with the CRT on, when asked to "pause and make it bigger", or when adding any readable world prop.
---
# Modal reader card

Reference: `scripts/ui/news_card.gd` (NewsCard), `scripts/interactive_mailbox.gd` (stand),
tests `test/unit/test_newspaper_stand.gd`.

## Build
- CanvasLayer `layer` under Transition/pause (99) and the CRT (100) so it is filmed through
  the tube; `process_mode = ALWAYS`; `get_tree().paused = true`, remember `_was_paused`.
- `CRTOverlay.tune_in(true)` while open (crisp grid); `HudFade.fade(CINEMATIC, 0)` so the HUD
  doesn't peek behind the card. HudFade tweens use `TWEEN_PAUSE_PROCESS` for this.
- Juice: dim, spin-in (2 turns, grows from a dot, punch 1.07 -> 1), thud on land, prompt
  pulses once armed, whoosh + drop on fold. Photos: crop sprite to `get_used_rect()` and
  print them two-tone with a canvas_item shader.
- Static `active` flag: PauseMenu ignores the pause key while it is set; the card folds on it.
- `_exit_tree`: if still active, unpause + `CRTOverlay.reset_focus()` + HUD back.

## Input rules (each was a real miss)
- Close = POLLED `Input.is_action_just_pressed` (the bot and touch buttons press actions)
  + `_input` for mouse/touch taps. Headless GUI hit-testing never delivered a test click.
- Arm window and the stand's reopen guard: unscaled SceneTree timers
  (`create_timer(s, true, false, true)`), NEVER `Time.get_ticks_msec`: headless autoplay runs
  ~60x faster than the wall clock, so a wall-clock guard never elapsed -> 3 scenarios timed out.
- Reopen guard after fold: a mash through the fold re-opened the paper on the unpause frame.
- Autoplay: runner waits while `NewsCard.active`, taps Interact after `ReadingTime.seconds`,
  and only while `active_text != ""` (not mid-fold).

## Validate
`crt on` autoplay verb; `snap_every 0.04` for motion; one `--resolution 1688x780` round;
contact sheets lie about position -> re-open the suspect frame full size. Mutation-check
each guard (tap, arm, pause key, pause, CRT, free-mid-read, photo wiring).
Any new on-paper TEXT needs user approval (artifact with options + live preview).
