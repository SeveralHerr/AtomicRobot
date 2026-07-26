# Devtools/Verify Gaps Log

Log of gaps in the global /verify or devtools workflow, and suggested improvements.

## 2026-07-26 — Add logging sections to CLAUDE.md

- Gap: This change was a docs-only edit (CLAUDE.md), so `/verify` doesn't apply (it's scoped to gameplay/script/scene changes) — nothing caught that these new "log at the end of every response" instructions are prompt-level conventions with no enforcement.
- Improvement: A lightweight `Stop` hook (or a `/verify`-adjacent check) that fails/warns when a response touched code but `log.md`/`log-devtools.md` weren't updated in the same turn would make this logging convention self-enforcing instead of relying on the model remembering every time.

## 2026-07-26 — Add "enhance used skills" rule + merge to main

- Gap: none — no code/gameplay change this turn, just a CLAUDE.md wording tweak and a branch merge, so `/verify` and devtools don't apply.
