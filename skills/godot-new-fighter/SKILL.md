---
name: godot-new-fighter
description: Add a new playable fighter (employee) to Atomic Robot from a sprite sheet - SpriteFrames matching the roster, select card, ranged shot spawn measured from the art, weapon sound timed to the hit frame, tests and side-by-side GIF evidence. Use when the user drops a new sprites/<Name>.png and says "add X to the game", "new employee", "new character", or asks to fix where a projectile leaves a hand.
---

# New fighter

Payton (2026-10-16) is the worked example: `sprites/payton_sprite_frames.tres`,
`scenes/fireball_bullet.tscn`, `test/unit/test_payton.gd`.

## 1. Read the sheet, do not guess

- 128 px grid sheets (Cass, Caitlyn, Robot, Payton): rows idle, crouch, walk, jump/climb,
  fall, attack, projectile, dead. Count frames per row from alpha bboxes.
- `python tools/fighter_frames_audit.py` (MCP `audit_fighter_frames`) prints every
  fighter's anims and where each frame stands: roster feet line is **+32** below the
  cell centre, legs within about ±6 of centre. Payton's art sat 22 px left: fix it in
  the regions (`Rect2(col*128 - 22, ...)`), never by editing the user's PNG. A negative
  region x is fine; Godot clips it.
- Build the .tres with a throwaway SceneTree + `ResourceSaver` (copy Cass's anim names,
  loop flags and fps). Throwaway scripts must `load()` inside a deferred method: a
  top-level `preload` or `Globals` reference compiles before autoloads exist.

## 2. Wire it like the others

`Globals.character_dict` entry, `character_select.gd` ROSTER + one more TICK_STEPS note,
`test_globals.gd` expected list, `tools/autoplay_sweep.py` CHARS, autoplay scenario copies
(`boss_balance_<name>.json`, `secrets_<name>.json` for a ranged one). Ranged: add an
`elif selected_character == "<Name>"` branch in `attack_state.gd` (test_damage_scale parses it).

## 3. The projectile must leave the hand

- Hit frame = the **first empty-handed attack frame**; the frame before it draws the release.
- Muzzle = head of the fireball in the release frame, mapped through DefaultSprite:
  `local = (cx + shift - 64 + 2, cy - 64 + 20 - 33.19)`. DefaultSprite has
  `offset (0, -33.19)`: forgetting it put Payton's shot 33 px low. Put it in a per-fighter
  marker node in `player.tscn` and pass it to `_shoot`.
- Test it by re-measuring both images through `global_transform` in both facings
  (`_check_spawn_spot` in test_payton.gd), not by comparing to the stored number.
- A muzzle far forward of the body skips maids in between: `_shoot` sets
  `origin_x` to the body's front edge.

Retrofitting an existing shooter (Cass, 2026-10-16): the same rules apply. When the
true release frame is later than the tuned hit frame, shorten the wind-up frames'
`duration` in the SpriteFrames so the release time and the mashed-chain time stay
put (assert both in frame units), and make every frame last at least 1/60 s.
Spin a thrown prop the way it flies (`signf(dir)`), and end it with a tumble or
ricochet instead of `queue_free` on the spot.

## 4. Sound

Weapon sounds start on swing frame 0. Put the loud transient at
`attack_frame / (15 * AttackChain.ANIM_SPEED)` s (0.19 s for frame 4). Synth recipe:
`tools/gen_fireball_sfx.py`. Imported WAVs are QOA; tests read the source RIFF.

## 5. Evidence

Capture each fighter separately with the same scripted input under `--fixed-fps 30`,
then compose side by side (reference | new). Collision debug (`debug_collisions_hint`)
only in a separate hitbox clip: it tints everything. Add a x0.2 slow-mo release with a
crosshair on the marker. Then sweep balance against the closest fighter
(`autoplay_sweep.py --chars Cass,<Name> --seeds 1..8`) and report gaps, do not retune silently.
