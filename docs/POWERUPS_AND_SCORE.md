# Power-ups and Scoring

Two systems shipped together, because they feed each other: power-ups make big
combos reachable, and the combo multiplier is what makes a power-up worth chasing.

**Hard constraint that shaped everything here: there is no new character art.** A
power-up may only change numbers the existing states already read, and recolour the
existing sprite through a shader. Nothing requires a new animation.

---

## Files

| File | Role |
|---|---|
| `scripts/powerup_rules.gd` | `PowerupRules` — definitions + all pure math (drop roll, stacking, shader blend, ramp). No side effects. |
| `scripts/autoload/powerup_system.gd` | `PowerupSystem` autoload — countdowns, applies stats to the live Player, writes shader uniforms. |
| `scripts/powerup_pickup.gd` / `scenes/powerup_pickup.tscn` | The dropped, collectable pickup. |
| `shaders/flash.gdshader` | Extended with `buff_*` uniforms (strict superset — hit flash unchanged). |
| `scripts/score_rules.gd` | `ScoreRules` — combo tiers, bonuses, rank table. Pure. |
| `scripts/autoload/score_system.gd` | `ScoreSystem` autoload — combo timer, stage clock, persistence, rank. |
| `scripts/score_ui.gd` / `scenes/score_ui.tscn` | Live HUD (score, combo, buffs). Hides when the run ends. |
| `scripts/high_score_table.gd` | `HighScoreTable` — top-10 list ordering, initials sanitising, save repair. Pure. |
| `scripts/ui/end_card.gd` / `scenes/end_card.tscn` | The one end-of-run card (atomic-pinball style): rank, score, initials, list, RESTART/EXIT. |
| `scripts/ui/initials_entry.gd`, `scripts/ui/score_table_view.gd`, `scripts/ui/comic_style.gd` | Card sections (initials entry, HIGH SCORES list) and the shared comic look. |
| `test/unit/test_powerup_rules.gd`, `test/unit/test_score_rules.gd` | 40 headless tests over both rule tables. |

All balance lives in the two `*_rules.gd` files. The autoloads decide *when*, never
*how much*.

---

## Power-ups

### The roster

| id | Effect | Look |
|---|---|---|
| `rage` | damage ×2 | hot red/orange recolour, slow 3 Hz throb, 6px dither cells |
| `overclock` | move speed ×1.6, attack rate ×1.75 | cyan recolour, fast 7 Hz throb, 4px dither cells |

Both last 8 seconds. Picking up one you already have **refreshes** it rather than
stacking — a lucky double-drop shouldn't produce a 16-second Rage that trivialises a
whole encounter.

Attack rate is real, not cosmetic: an attack lasts exactly as long as its animation
(see `AttackState`), so `AnimatedSprite2D.speed_scale` genuinely raises DPS.

### How the stats reach the player

`Player` gained two fields written **only** by `PowerupSystem`:

```gdscript
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
```

read back through `get_damage()` and `get_speed()`. They are multipliers rather than
in-place edits to `damage`/`SPEED` because those two hold character-config baselines
that a buff expiring mid scene-change must never be able to corrupt.

Every place that used to read `player.damage` now goes through `Player.land_hit()`,
which applies the buffed damage **and** feeds the combo meter — so scoring cannot
drift out of sync with damage dealt. Call sites: `attack_state.gd` (×2),
`robot_bullet.gd`, `flipflop_bullet.gd`.

### The visual (and why it's screen-space)

The character `SpriteFrames` are `AtlasTexture` regions packed into one sheet. Any
effect that offsets or quantises `UV` — a neighbour-sampled outline, a UV-space
pixelate — reads a **neighbouring frame** and smears the wrong animation frame across
the sprite. So the buff overlay is computed from `FRAGCOORD` instead: a chunky
screen-space checkerboard the character moves through, tinted to the buff colour and
throbbing at its pulse rate.

`PowerupRules.ramp_strength()` fades the overlay in over the first 12% of the
duration and out over the last, so a buff never pops on or off.

### Shader installation is at runtime, deliberately

The player node is **inlined into three scenes** (`player.tscn`, `main.tscn`,
`boss_room.tscn`), each carrying its own *embedded copy* of the flash shader. Patching
all three would be three edits that silently rot the next time someone re-inlines the
player.

Instead `PowerupSystem.attach()` (called from `Player._ready`) swaps the `Shader` on
the **existing** `ShaderMaterial`. Keeping the same material object matters: the "Hit"
AnimationPlayer tracks write
`DefaultSprite:material:shader_parameter/flash_value`, and they keep resolving.
`flash_color` is restated to white on install, because swapping a shader clears its
parameters and an unset colour reads as transparent black — which would turn every
hit flash into a hit *blackout*.

The extended shader is a strict superset with all `buff_*` uniforms defaulting to 0,
so the enemies that reference `flash.gdshader` directly are unaffected.

### Drops

Rolled in `Enemy.die()` → `PowerupSystem.roll_drop()` → `Utils.drop_powerup()`.

- 22% base chance per kill.
- **Pity floor at 8 kills.** A pure 22% roll has a ~14% chance of an 8-kill drought,
  which reads in play as "power-ups are broken" rather than "unlucky". The counter
  lives on the autoload (a property of the run) and resets on player death.
- The roll happens in `die()`, before the body's 1.5s death fade, so the pickup lands
  while the fight that earned it is still going.

Pickups hover `HOVER_HEIGHT` (18px) above the **lane's floor line**, not above the
enemy's origin — origins sit different distances above their soles (a maid's 27px, the
player's 19.75px), so an origin-relative drop would float at a visibly different
height per enemy type. They live 12s and blink (accelerating) for the last 3.

The sprite is deliberately small (`scale 0.013` on `Logo_small.png`) so a drop reads
as an item lying in the street rather than a billboard. The pickup radius (22px) stays
noticeably larger than the art so collection still feels forgiving.

Collection requires the player to be **on the same lane**, matching the rule combat
already uses. Overlap alone can't express that: lanes are 24px apart and the pickup
radius is 22, so the `Area2D` genuinely overlaps two or three lanes. It's **polled**
against the live overlap set rather than latched on `body_entered`, because the player
very often walks into the radius on the wrong lane and only *then* taps across —
`body_entered` has already fired and won't fire again. (Same fix, same reason, as
`Enemy._refresh_player_in_attack_range`.)

---

## Scoring

### During a stage

- **Hit** — combo +1, worth `10 × multiplier`.
- **Kill** — worth `100 × multiplier`. Refreshes the combo window but does *not*
  advance the count: the killing blow was already counted as a hit, and counting it
  twice would let one swing jump two tiers.
- **Getting hit** — combo to zero, `damage_taken` +1. Hooked into
  `Player.take_damage()`, which every damage source already funnels through, and
  which returns early in `god_mode` — so the debug cheat can't cost you a combo.
- **2.5s window** without landing a hit drops the combo.

Multiplier tiers start at combo 0, 3, 6, 10, 15, 21, 28, 36 → 1× to 8×. Front-loaded
so the meter feels alive in a normal three-enemy scrap, then stretched so 8× is a
genuine achievement.

### End of stage

```
total = fight_score + time_bonus + no_damage_bonus
```

- **Time** — 25 pts per second under a 240s par. Never negative; being slow costs you
  the bonus, it doesn't subtract from what you earned fighting.
- **No damage** — flat 3000 for a flawless run, otherwise 250 per health pip left. A
  flawless run beats *any* damaged run outright, whatever health was kept (pinned by
  a test).
- **Rank** — S 20000 / A 14000 / B 9000 / C 5000 / D 0.

Bests persist per scene to `user://scores.cfg`.

### Stage boundaries are detected, not declared

`ScoreSystem` watches the current scene rather than having levels call
`begin_stage()`. Levels are hand-edited in the editor, and a forgotten call would
silently produce a stage that never scores. Polling can't be forgotten. Scored scenes:
`main.tscn`, `boss_room.tscn`, and everything under `res://test/scenes/` (so combo can
be asserted from a sandbox).

It keys on the scene's **instance id, not its path**. `project.godot` boots straight
into `main.tscn`, so the two most common restarts — the devtools `start_game` verb and
retrying after a death — both reload the scene that is already loaded. A path
comparison sees no change, which left the clock running from the previous attempt and
the HUD parented to the freed scene. (Caught at runtime by `/verify`, not by lint or
the unit tests — `hud_present: false` with a `stage_seconds` larger than the session.)

A player death ends the run with **no** rank card — you don't get graded on a stage
you didn't finish.

### End card and high-score list

Both levels end on ONE screen, `UI/EndCard` (`scripts/ui/end_card.gd`), styled after
atomic-pinball's game-over card so both cabinet games match: white comic card (ink
border, hard shadow, -1.5° tilt) over the dimmed level. Left: GAME OVER / YOU WIN!,
the rank stamp (clears only, slams in), FINAL SCORE, the clear breakdown, the
"NEW HIGH SCORE!" / "YOU PLACED #N!" badge. Right, past a dashed rule: ENTER YOUR
INITIALS if the run made the list, replaced in place by HIGH SCORES (new row lit)
once saved. Foot: RESTART / EXIT GAME, hidden until the initials are in. It replaced
the old Game Over / You Win containers and the HUD's rank card, so nothing stacks.
It also hides the level's touch controls (they eat taps by position) and the HUD
hides its rolling score, which would disagree with the final total.

ScoreSystem connects to `Globals.player_death` / `boss_death` before any level, so
`ScoreSystem.last_run` (`won`, `total`, `rank`, `slot`, breakdown) and
`awaiting_initials` are already set when the card reads them.

One game-wide top 10 (`user://scores.cfg`, section `high_scores`, plus
`last_initials`). A run qualifies when it beats 10th place (a tie does not), on a
clear or on a death with a score. Only `ScoreRules.SCORED_SCENES` write to it.

Initials (same rules as pinball): A-Z only, pre-filled with the last initials used;
cursor walks the three letters then OK. Stick/d-pad up/down dials (hold repeats),
left/right moves, JUMP next / save on OK, B back; keyboard types (W/A/S/D type, they
do not move); touch has arrows per letter (≥104×88 design px) and OK. Input ignored
for the first 0.6s (jump-mash guard). Left idle 30s it saves the letters showing.
The title screen's attract loop swaps in a small tilted HIGH SCORES card every 6s.

The save file is user-editable, so the list is rebuilt through
`HighScoreTable.from_variant()` on load (junk rows dropped, re-sorted, initials
re-sanitised to A-Z).

### HUD injection

`score_ui.tscn` is a self-contained `CanvasLayer` (layer 1, under the levels' UI
layer 2 so the end card covers it) that `ScoreSystem` adds to
the scene root when a scored stage begins, rather than being authored into each level.
It's driven entirely by autoload signals, so there's nothing to wire per level, and
one injection point covers both levels plus every sandbox instead of three copies that
drift apart.

Score, combo and the active-buff timers stack in a single column centred at the top of
the screen, set in the character-select face (`styles/white_font.tres`, Bangers). It
begins at y=126, below the health orbs (top-**left**, running to x=544, y=118) — the
column is wide enough that a long buff line would otherwise clip them.

#### Animation

Every live element animates off a **decaying float ticked in `_process`**, not off a
`Tween`. Hits, kills and pickups arrive faster than a tween's duration in a real scrap,
and overlapping tweens on the same property fight each other and strand a label scaled
or tinted — the failure `health_container.gd` needs per-orb tween bookkeeping to avoid.
Re-setting a float to 1.0 on each event simply restarts the animation.

- **Combo** — just the hit count (`7 HITS!`), no multiplier prefix and **no timer bar**.
  Each hit scrolls the line up from below with a scale punch (a bigger one when the
  multiplier tiers up, since the `x3` that used to announce it is gone), then the line
  fades and drifts upward as the window drains. *The fade is the timer* — that is why
  the `ProgressBar` was removed. Tier colour still comes from `MULTIPLIER_COLORS`.
  It lives in a fixed-height `ComboSlot` `Control` rather than directly in the
  `VBoxContainer`, so it can own its own `position` — a container re-sorts its children
  every time the text changes width and would fight the animation.
- **Score** — punches and flashes toward the current tier colour on each award, scaled
  by the award's size, so an 800-point kill reads differently from a 10-point jab.
- **Buffs** — pop on `powerup_started`, then blink through the last 1.5 seconds.

`combo_fraction()` reaching 0 while `combo > 0` is not a reachable game state
(`register_hit()` sets both together), so the readout treats it as expired and hides.
The `set_combo` devtools verb refreshes the window for that reason.

---

## DevTools verbs

```bash
python tools/devtools.py cmd grant_powerup  --args '{"id":"rage"}'
python tools/devtools.py cmd clear_powerups
python tools/devtools.py cmd drop_powerup   --args '{"id":"overclock","lane":2}'
python tools/devtools.py cmd powerup_state
python tools/devtools.py cmd score_state
python tools/devtools.py cmd set_combo      --args '{"combo":15}'
python tools/devtools.py cmd finish_stage
```

These exist because the generic primitives can't reach any of it: the buff timers live
in an autoload (not a scene node, so `get-state` can't find them), the only proof the
visual is live is a set of **shader uniforms on a material** (not a node property), and
the drop table is a random roll a test has to be able to bypass. `powerup_state`
reports the uniforms actually written to the sprite material for exactly that reason.

---

## Tuning cheat-sheet

| Want to change | Edit |
|---|---|
| Buff strength/duration/colour | `PowerupRules.DEFS` |
| How often power-ups drop | `PowerupRules.BASE_DROP_CHANCE`, `PITY_KILLS` |
| How chunky the pixel effect is | `pixel_size` / `dither` per def |
| Combo pacing | `ScoreRules.MULTIPLIER_STEPS`, `COMBO_WINDOW` |
| Rank difficulty | `ScoreRules.RANK_THRESHOLDS` |
| Par time | `ScoreRules.PAR_SECONDS` |

---

## Not built (deliberate scope edges)

- Only Rage and Overclock ship. Invincibility and Magnet were considered and cut.
- Power-ups drop from enemies only — not from crates, mailboxes or windows.
- No collection/secrets component in the score.
- No leaderboard beyond a single persisted best per stage.
