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
