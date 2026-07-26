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
