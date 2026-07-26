# Devtools/Verify Gaps Log

Log of gaps in the global /verify or devtools workflow, and suggested improvements.

## 2026-07-26 — Add logging sections to CLAUDE.md

- Gap: This change was a docs-only edit (CLAUDE.md), so `/verify` doesn't apply (it's scoped to gameplay/script/scene changes) — nothing caught that these new "log at the end of every response" instructions are prompt-level conventions with no enforcement.
- Improvement: A lightweight `Stop` hook (or a `/verify`-adjacent check) that fails/warns when a response touched code but `log.md`/`log-devtools.md` weren't updated in the same turn would make this logging convention self-enforcing instead of relying on the model remembering every time.

## 2026-07-26 — Add "enhance used skills" rule + merge to main

- Gap: none — no code/gameplay change this turn, just a CLAUDE.md wording tweak and a branch merge, so `/verify` and devtools don't apply.

## 2026-07-26 — Implement the logging Stop hook

- Gap: closed. Implemented the `Stop` hook suggested above: `tools/check_logging.sh` diffs this branch against `main` and, if code/gameplay files changed without `log.md`/`log-devtools.md` also changing, prints a `systemMessage` reminder (non-blocking — it warns, it doesn't fail the turn).
- Remaining gap: the check is scoped to code/gameplay file patterns (`.gd/.tscn/.tres/.import`, `scenes/scripts/sprites/Tiles/Sounds/addons`), so a non-code response still relies on the model remembering to log; and it's advisory only, so a model that ignores the warning isn't blocked. Could be tightened later to `decision: "block"` if warnings prove easy to ignore.
