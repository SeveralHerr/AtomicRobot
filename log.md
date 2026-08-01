# Skills Log

Log of skills that might have been useful for a given response, and why (short form).

## 2026-07-26 — Add logging sections to CLAUDE.md

- `update-config` — flags that "do X at the end of every response" behaviors are memory/prompt conventions, not enforced hooks; relevant caveat, but not used since the user explicitly wanted a CLAUDE.md instruction, not a settings.json hook.

## 2026-07-26 — Add "enhance used skills" rule + merge to main

- No skills were used this turn (plain doc edit + git/GitHub operations); none of the available skills fit small text edits or merging a branch.

## 2026-07-26 — Implement the logging Stop hook

- `update-config` — used to add the Stop hook to `.claude/settings.json` (hooks are the right primitive for a per-turn automated check, not a CLAUDE.md instruction). Enhancement idea, in simple words: give the skill a few ready-made hook recipes (like "warn if file A changed but file B didn't") so it doesn't have to hand-write the shell script from scratch every time.

## 2026-07-26 — Retire enemies on death, not when the corpse frees

- `godot-selftest-harness:verify` — used. It caught nothing wrong, but its Phase 2 launch is where the run fell over: the test player was killed by ambient waves and the game exited, taking the bridge down mid-test. Enhancement idea, in simple words: after the entry hook, have `/verify` make the test player unkillable, and check the game is still alive before each command so a dead game says "game not running" instead of hanging for a minute.
- `simplify` — would have been useful and wasn't run. The fix added the same `_is_alive()` helper to both `enemy_event.gd` and `building_door_encounter.gd`; a reuse pass would likely have pulled it up to a shared static on `Enemy` instead of copy-pasting it.
- `fewer-permission-prompts` — marginal. Several read-only `python tools/devtools.py ...` calls prompted, and one got denied mid-test; an allowlist for the devtools CLI would smooth out future runtime verification.

## 2026-07-26 — Log the harness gaps to README + memory

- No skills used or needed — a README edit, a memory-file update, and git operations. None of the available skills cover small doc edits or committing.

## 2026-07-26 — Move the logs into log.md / log-devtools.md

- No skills used or needed — reading the updated CLAUDE.md and appending to two log files. No available skill covers "follow a repo's own logging convention".

## 2026-07-25 — Animate the HUD orb losing a hit point

- `godot-selftest-harness:verify` — used. Lint/tests were clean; the runtime phase is what proved the change (mid-tween `modulate` reads + a screenshot of the flare) and also exposed that the orb shader was throwing `modulate` away. Enhancement idea, in simple words: let `/verify` freeze the game clock and step it by a fixed amount, so an animation can be checked at an exact moment instead of guessing with slow-motion and sleeps.
- `simplify` — not run; would have been a reasonable pass over `health_container.gd`, which still carries an empty `_process` and a mix of typed/untyped locals from before this change.
- A skill that doesn't exist and would have helped: something like "godot-tween-effects" — a small library of reusable UI juice tweens (punch, shake, pop-out) so damage/pickup effects don't get hand-written per project.

## 2026-07-25 — Commit the HUD damage animation and the leftover working-tree changes

- No skills fit — branching, reviewing three diffs I hadn't written, and committing. `/verify` was already run on the code change in the previous turn and nothing gameplay-related changed here.
- A skill that doesn't exist and would have helped: something like "godot-scene-diff" — tell whether a re-saved `.tscn` actually changed behaviour or just churned format. Doing it by hand meant dumping both versions through `tools/dump_level.gd` and diffing the JSON.

## 2026-07-25 — Diagnose the one-attacker wave bug, fan out approach A

- No skill was invoked this turn — the work was reading `enemy.gd` / `lane_system.gd` / `globals.gd` to find why only one enemy attacks, then splitting the fix across three subagents by file ownership. No available skill covers "partition an edit so parallel agents can't collide".
- `godot-selftest-harness:verify` — not yet run; it is the gate for the next turn, once all three agents have landed their edits. Enhancement idea, in simple words: let `/verify` take a list of files and check only what those files affect, so a three-way parallel change can be verified per-part instead of only at the end.
- `simplify` — worth queueing after the agents finish. The change deletes `_lane_is_claimed` and shrinks `_pick_chase_lane` to a one-liner, which is exactly the kind of leftover a reuse/altitude pass should collapse.
- A skill that doesn't exist and would have helped: something like "godot-dead-code" — find autoload APIs that are fully written and unit-tested but never called from gameplay. The whole bug was that `Globals`' attack-slot manager had passing tests and zero callers, and nothing surfaced that; its own docstring pointed at a function (`_chase_toward_player`) that never existed.

## 2026-07-25 — Exempt the boss from the attack-slot pool

- No skill invoked — a three-file follow-up fix surfaced by a subagent's report (the boss holding a ranged slot for the whole fight), plus a lint run.
- `godot-selftest-harness:verify` — still pending until the test agent lands; the `test/scenes/melee_cluster.tscn` / `ranged_cluster.tscn` / `mixed_cluster.tscn` sandboxes are the right runtime targets for this change.
- A skill that doesn't exist and would have helped: something like "godot-state-reachability" — given a state machine, report which states have no exit transition. The boss bug was exactly that (`BossAttackPlayerState` is entered in `_ready()` and never left), and it only came to light because an agent read the file by hand.

## 2026-07-25 — Verify approach A at runtime

- `godot-selftest-harness:verify` — used, and it was the only thing that could prove this change (lint + 114 unit tests passed on the broken version too). Enhancement idea, in simple words: let `/verify` keep the test player alive by itself, because the fight killed the player three times before a single measurement succeeded, and each death silently froze every reading at zero instead of saying "your player is dead".
- `simplify` — still queued and now clearly worth running: the change left `_pick_chase_lane` inlined and `_lane_is_claimed` deleted, and I added a `competes_for_attack_slots()` predicate that replaced a duplicated `lane_locked` check in two files.
- A skill that doesn't exist and would have helped: something like "godot-crowd-assert" — sample a running fight over time and report peaks (how many attacking at once, who is on which lane). I hand-wrote four throwaway Python samplers to get numbers that should be one command.

## 2026-07-25 — Add revive/god_mode/attack_slots devtools verbs

- No skill invoked — adding project verbs to `devtools_ext/commands.gd`, a generic status hook to the harness core, and a path fix to `devtools.py`, then committing to two repos.
- `godot-selftest-harness:verify` — not re-run in full; this turn changed only debug tooling, and the gameplay change it gates was already verified and committed. Lint + 114 tests were re-run clean, and each new verb was exercised live.
- A skill that doesn't exist and would have helped: something like "plugin-release" — bump the version, update the changelog, and push a Claude marketplace plugin in one step. Doing it by hand means remembering which of `plugin.json` / `marketplace.json` carries the version.

## 2026-07-25 — Fix the slot desync and upstream the input patch

- No skill invoked — a one-line root-cause fix, two regression tests, and a file sync between two repos.
- `godot-selftest-harness:verify` — not run in full; lint + 116 tests are clean and the fix was confirmed live with the new `attack_slots` verb across a player death. The verbs added last turn are what made that a single command instead of a hand-written sampler.
- A skill that doesn't exist and would have helped: something like "mutation-check" — reintroduce a fix's root cause, confirm the new test fails, then restore. I did that by hand this turn and my restore path was wrong, so the bug briefly stayed reintroduced; a skill that owns the backup/restore step would not have slipped.

## 2026-07-26 — Juice the score/combo/power-up HUD and outline the HP label + logo

- `godot-selftest-harness:verify` — used, and it earned its keep twice. Lint caught a shader-compiler error I had just introduced (Godot cannot take the built-in `TEXTURE` as a user function argument), and `validate-ui` caught the combo label sitting visible-but-fully-transparent when no combo is running. Neither is visible in a screenshot. Enhancement idea, in simple words: let `/verify` take a "before" reading of the noisy numbers (orphan nodes, UI warnings) on the unchanged code automatically, so it can say "these 3 warnings were already here" instead of leaving me to stash my work and relaunch the game twice to find that out by hand.
- `simplify` — not run; the change is additive and the one helper I wrote badly (a `_tint()` that looked its cache up by string name) I replaced by hand before committing.
- A skill that doesn't exist and would have helped: something like "godot-uv-shader-preflight" — given a shader and the nodes it is assigned to, report the drawn pixel size and aspect of each one, and warn when a UV-space radius will come out anisotropic or will be clipped by the art's own margin. Both problems were real here (a 794x500 logo would have got a rim 1.6x fatter top-and-bottom, and only ~1.4% of vertical margin to draw it in), and I only caught them by measuring the PNG's alpha bounding box in Python first.

## 2026-07-31 — Mobile controls relayout (joystick left, actions right)

- `run` — would have helped: launching + screenshotting the game to confirm the touch
  layout; I drove it by hand through the devtools bridge instead. Enhancement idea:
  teach it to auto-run the project's `entry_hook` so the first screenshot is of the
  playable scene, not the start screen.
- `simplify` — not used, but a good follow-up on `scripts/mobile_ui.gd` now that the
  per-finger tracking replaced the copy-pasted per-button branches.
- A "godot-scene-layout" skill would have helped had it existed: editing anchors and
  offsets in `.tscn` text by hand is error prone, and there is no headless way to ask
  Godot "what rect would this control get at 1280x800" without running the game.

## 2026-08-01 — Pull main, resolve the log conflicts, commit the HUD work

- No skill invoked — committing a working tree, merging one commit, and resolving two
  append-only log conflicts. `godot-selftest-harness:verify` was deliberately not run in
  full: nothing was authored this turn, and the merge was non-overlapping (theirs moved
  `MobileUI` anchors, mine added a HUD material), so headless lint + the 125 unit tests
  were the proportionate gate. Both passed.
- A skill that doesn't exist and would have helped: something like "append-log-merge" —
  auto-resolve conflicts in files that are only ever appended to (changelogs, these two
  logs) by keeping both sides in date order. Git conflicts on every one of these merges
  and the resolution is mechanical every time.
- A second one worth having: "godot-post-pull" — run `--import`, then diff which
  generated `.uid` files are newly untracked. The incoming commit shipped
  `test/unit/test_mobile_controls.gd` without its `.gd.uid`, which the other 122 scripts
  all have; only a reimport surfaced it.

## 2026-08-01 — Re-scaffold the godot-selftest-harness

- Used `godot-selftest-harness:scaffold-godot-harness`. It was a refresh, not a first
  install: the addon core, all four tool scripts, the example extension, and the
  CLAUDE.md section were updated in place; `devtools_ext/commands.gd`, `test/unit/`,
  and `log-devtools.md` were correctly left alone; `devtools_config.json` was patched
  to add the six new keys while keeping this project's `hud_layer_name: "UI"`,
  `main_scene`, and `entry_hook`.
  - Enhancement idea, in simple words: the scaffolder should **say what changed** at the
    end — a short list of "refreshed / created / left alone / backed up" per file. Right
    now you only learn `dev_tools.gd` gained 714 lines by running `git diff` yourself,
    and the three `.bak` files it leaves behind look like junk unless you go diff them.
  - Second idea: it should **check the DevTools autoload is last** in `project.godot`,
    not just present. Here it sits above five game autoloads that the project's own
    debug verbs call into. Nothing broke (the verbs run later, not at registration),
    but the ordering rule the command itself states is silently violated.
- `godot-selftest-harness:verify` was not run: nothing about gameplay changed, so
  headless lint + the 125 unit tests were the right-sized gate for a tooling refresh.
- A skill that would have helped had it existed: "godot-fix-uids" — the lint smoke check
  surfaced 9 pre-existing stale-UID errors and the remedy is a documented one-liner in
  CLAUDE.md, but deciding whether rewriting nine `.tscn` files counts as in-scope for a
  scaffold is a judgment call a small dedicated skill could just own.

## 2026-08-01 — Lane baseline anchored to street level

- `godot-selftest-harness:verify` — used. Caught nothing new here (lint/tests were
  already green before it), but it is what forced the runtime check of the platform
  case rather than trusting the unit tests. Enhancement idea: let it print, per changed
  file, which runtime test covered it — so a script that got no runtime coverage is
  named out loud instead of blending into a green summary.
- A skill that would have helped, had it existed: **"repro a reported gameplay bug"** —
  take a screenshot/description, find the geometry involved, drive the game into that
  exact situation, and confirm the misbehaviour BEFORE the fix. Most of the runtime time
  this turn went into locating a platform and standing on it.
- `simplify` / `/code-review` — not used; the change is small and self-contained.

## 2026-08-01 — README, controls page, web-font glyph fix

- No skill was invoked this turn (the work was scene/doc editing plus runtime screenshots).
- Would have helped, had it existed: **"capture a game screenshot for docs"** — launch,
  reach a representative moment, compose it (spread enemies, full health, good backdrop),
  save into the repo and reference it from a doc. Doing it by hand took 5 candidate shots
  and 3 relaunches.
- `godot-selftest-harness:verify` — not run as a whole this turn; its Phase 1 (lint,
  tests) and Phase 3 (validate-ui, performance) steps were run individually because the
  work was UI layout that needed a screenshot loop, not a diff assertion. Enhancement
  idea: a lighter `/verify ui <scene>` entry point that loads one scene, validates it and
  screenshots it, without the full launch-and-assert-the-diff pass.

## 2026-08-01 — Commit split

- No skill invoked; this was git work. No skill in the list would have helped, and none
  is obviously missing - `/code-review` would have been the one to reach for had the
  request been "check this before committing" rather than "commit it".
