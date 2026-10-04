---
name: godot-feedback-fanout
description: Turn a player's playtest notes on Atomic Robot into parallel fixes with before/after GIFs — split notes by file ownership, fan out one agent per group in worktrees, merge, balance LAST, record, publish a GIF page. Use when the user pastes player/playtester feedback, a bug list from a friend, or "address these notes with subagents".
---
# Player feedback → fan-out → GIF page

## 1. Split by FILE OWNERSHIP, not by note
Notes cluster into groups that touch disjoint files (2026-10-04 round):
- combat feel: `Player.gd`, player states, `scripts/combat/*`, SFX pitch
- numbers: `globals.gd` character_dict, `enemy.gd` health, bullets, `damage_rules.gd`, BossRules
- enemy AI: enemy states, `scripts/enemy/*`, `coin_bullet.gd`
- presentation: camera limits, announcer, mailbox/news, end card, score UI
- balance (LAST, after merging the rest) and polish (fallout of the others)
Write the cross-group CONTRACT into both prompts (e.g. `reflect(by)` + group "reflectable";
`receive_hit(damage)`); name who owns a shared line (enemy "oof" sound line → combat).

## 2. Worktrees
`git worktree add -b pf-<g> C:/Users/gotmi/wt-pf-<g> player-feedback` (OneDrive paths too long).
Integration worktree `C:/Users/gotmi/wt-pf` on the feature branch — never check out over
`main` when `main` has someone's staged WIP. Agents don't merge; the orchestrator merges
each branch, resolves `log.md` (keep both), runs ALL suites after every merge.

## 3. Required per agent
- before/after GIF per visible change, same scripted input, ≤640 px, ≤3 MB, into
  `scratchpad/pf-<g>/pf-gifs/` (skills/godot-ab-worktree for HEAD vs tree).
- failing test first, mutation check (`python tools/mutate.py`), suite counts in report.

## 4. Balance last
Faster combat halved hits taken (18 → 8); the player's own levers (enemy speed, wind-up,
+1 enemy per door) restored it. Rank thresholds re-pin after balance, from measured runs.

## 5. Record AFTER, once
Don't record a "before" video up front — the user wants the run at the end; per-change
GIFs carry the before/after. `python tools/autoplay.py completionist_mortal --record out.mp4`,
1 fps sheets, re-extract suspects full size, fix what the footage shows (KO! under STREET CLEAR!).

## 6. Page
Plain artifact: video + one panel per player quote, before/after GIF pair, bullets. Keep
UI-noise feedback in mind: the user cut a rank-chip row as "too much noise" — prefer one line.
