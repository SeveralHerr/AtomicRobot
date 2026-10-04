---
name: godot-boss-juice
description: Build or rework a boss fight / set-piece in Atomic Robot (or any Godot 4 brawler) with game feel — intro cinematic, phase banners, attack waves, HUD boss card, finale — and balance it with the autoplay bot. Use when asked to "make the boss better", add juice/presentation to a fight, add phases or attack waves, or rebalance a boss.
---
# Boss fight juice + balance

Reference implementation: `scripts/boss/` (rules table, banner, HUD card, juice helpers,
drop marker), `scripts/boss_room.gd` (director), `scripts/states/boss_*_state.gd`.

## Shape
- **One tuning table** (`BossRules.PHASES`): per phase title/sub/line, throw cadence, fan,
  drops, maids, dash. Tests pin the *ramp* (each phase harder, adds an attack), not numbers.
- **Director** (room) listens to boss signals `health_changed / phase_changed / defeated`.
  Connect `phase_changed`/`defeated` **CONNECT_DEFERRED** and start the intro with
  `call_deferred` — they fire inside physics callbacks and spawn/kill Area2D bodies
  ("Can't change this state while flushing queries").
- Boss inert until `begin_fight()`; invulnerable while `staggered` (phase beat) and after
  the killing blow. Emit the game-over signal after the finale, not on the hit.

## Presentation checklist (each was a real miss)
- Text: stripe sweep + tilted inked title slam + subtitle on an ink tag; "FIGHT!"/KO in a
  starburst; boss lines in a speech bubble over his head with typewriter blips. Replace the
  old labels — don't layer a second text system.
- Banner tweens/timers ignore time scale, or a slam during slow-mo crawls.
- Custom `_draw`: setters must `queue_redraw()` — redrawing only "while visible" leaves the
  last frame (a tiny starburst) stuck on screen.
- CRT overlay: the bezel swallows ~40px of every edge; black letterbox bars must be tall
  (top) and must not cover the fighters (bottom stays thin).
- HUD boss card: top-right under the logo — not top-centre (score/combo rows) or the bottom
  (feet + bezel). Animate an inner node, never the anchored Control itself.
- Never tween `scale` on a Container child (layout resets it).

## Fairness rules
- Lock aim at the wind-up tell, not the release frame, or throws are undodgeable.
- One fan = one hit (`link_fan`): knockback otherwise juggles the player through the fan.
- Telegraph area attacks (floor markers) and keep a guaranteed gap (`drop_xs`).
- Give a heal at each phase change for the low-HP characters.

## Balance loop
`python tools/autoplay_sweep.py --seeds 1,2` -> read `boss_hp` per character -> count
`hurt` events by `near` to find the culprit attack -> change ONE table value -> repeat.
Then pin with seeded mortal scenarios both ways (must-win tank, weak char reaches half).
Visual rounds: `snap_every 0.3` windowed + contact sheet; one `--resolution 1688x780` round.

## Reusing the banner off the boss stage (street door waves)
`EncounterAnnouncer` hosts a `BossBanner` on its own CanvasLayer (3: above HUD, below
pause/CRT) and only listens to encounter signals. Street callouts: `size_k = 0.8`,
`stripe_y = 0.36` (waves) / `0.42` (payoff) so stripe and burst clear the HP row,
the score and the walkway maids. Size the banner by hand with TOP_LEFT anchors (a
first slam lands the frame it is added; full-rect + `size =` logs a warning). Wave
callouts on BLUE (yellow-on-orange washed out), last wave RED. Payoff is `STREET CLEAR!`
(user's call, over `BUSTED!`) even though ambient maids can still be up after the squad dies. A forced end (death/watchdog) hides the layer.
Payoff burst now sits at `CLEAR_Y 0.45`, `k 0.5`; mid-door waves get a smaller sting-less
`WAVE CLEAR!` (`wave_cleared` signal, `k 0.4`). Every callout goes through `_slam()`.

## HUD vs callouts and cinematics (`HudFade`, scripts/ui/hud_fade.gd)
- No room for a burst between the power-up timer stack (~y 241-340) and the player's head:
  callouts DUCK `HudFade.POWERUPS` instead of moving. Pin it with a derived check: lay the
  real `score_ui.tscn` out in a SubViewport and require every `Hud/Rows` child the burst
  rect reaches to be in the duck group (`test_announcer_clear_burst_covers_only_ducked_hud_rows`).
- Anything HudFade tweens must not be written per frame elsewhere: the timer blink moved to
  `self_modulate`. Cinematics fade `HudFade.CINEMATIC`; the fade alpha is HELD for late
  joiners (ScoreSystem injects the score column after the boss intro has started) and
  released on fade-in / `boss_room._exit_tree`. Orbs are z_index 2 (draw over the bars):
  fade out before `letterbox_in`, back with `delay = LETTERBOX_TIME` after `letterbox_out`.
- Real-time tweens in unit tests: `await process_frame` first — the first frame after a
  scene load carries the whole load as its delta and runs a 1s duck start-to-finish.
- Godot 4.7: `get_meta(key, null)` treats null as "no default" and logs an ERROR (autoplay
  counts it). Guard with `has_meta`.
