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
