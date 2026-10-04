---
name: godot-speedrun-review
description: Record a human-like 100% speedrun of Atomic Robot (every heart, power-up, secret wall, newspaper) to MP4 and turn the footage into a reviewed suggestion list (presentation, balance, fun, juice). Use when asked to "record a playthrough/speedrun", "make a video of the game", "watch the run and suggest improvements", or to refresh the review artifact after big changes.
---
# Speedrun → footage → suggestions

## 1. Route (already scripted)
`test/autoplay/completionist_run.json` (god on, CI-pinned: `heals >= 6`, won). For a
mortal "human" take, copy it without `god on` and try seeds 1-4 headless first
(~6 s wall each); pick one that wins and grabs both `rage` and `overclock`
(`--events powerup,heal,death`). Secrets the brain can't see are scripted steps:
- `tap Interact` at newspaper stands x -779, 306, 1494, 3218, 5028 (brain never presses E).
  `brain advance` ends on a ROAD lane: `lane 0` + `walk_to X` before the tap, or the stand's
  23 px circle misses you (5028 was silently skipped until `secret_news == 5` was pinned).
- Any character opens wall B (Robot/Cass shots chip it); `test/autoplay/secrets_cass.json`
  is the fast check (~1 s). Windowed runs drop more taps (wall-clock hitstop): 9 taps.
- Hidden heart x -1410 (walk left first); street heart 2944 is behind the crate stack:
  approach on a ROAD lane, `lane 0` at 2944. Roof heart 3208: from x 2700 lane 0, hold
  right + 6 jumps (bins are steps).
- Secret wall B: fire escape x 3765, 8 × (`press ui_accept`, 0.32 s, release, 0.42 s),
  face left, `tap Attack` with **0.6 s** gaps (taps mid-swing are dropped), `tap Interact`.
- Wall A (cat, x 391) is UNREACHABLE today (bottom rung 190 px, jump apex 88 px).
- `brain advance S X` fights forward and stops at x=X — the glue between secrets.

## 2. Record
`python tools/autoplay.py <scenario> --record autoplay_out/run.mp4` (or MCP
`record_autoplay`). Movie Maker is windowed, keeps sound, ~1x real time.
- Hitstop used to hang Movie Maker (time_scale 0 → NaN unscaled delta). Fixed via
  `Utils.hit_pause_scale()`; if a recording crawls, grep its log for
  "cannot be normalized" — that is the same class of bug.
- Hitstop is wall-clock: a recorded run is NOT frame-identical to the headless run.
  Check the recorded report (`won`, hp at end) before using the footage.
- Artifact publish cap 15 MB: two-pass, 1024x640, 30 fps. Pick `-b:v` from length:
  `(15 MB*8 / seconds) - 40k audio` minus ~10% (3:15 → 520k; 4:21 → 400k ≈ 14.6 MB).
- A recorded MORTAL take can die where headless never does: scripted `walk_to` doesn't
  fight, and a maid that spawns after `brain clear` chain-hits the walk (round 3 died at
  1:04, retake won). Retry once before changing the route; check the recorded report.

## 3. Review
- `fps=1/2` frames → PIL 4x4 sheets with a timecode label per tile. Read every sheet.
- Adjacent thumbnails can fake a bug (two tiles of one sign read as a doubled sign):
  re-extract the exact frame at full size before calling it a finding.
- Cross-check the report: `hurt` events by `near` (who hurts you), heal/powerup times,
  hp entering each scene, score before/after a scene change.
- One card per finding: timecode, what was seen, proposal, effort/impact.
- Before claiming "X fires at the wrong time", check WHICH encounter you're looking at:
  two doors back to back looked like one door's "STREET CLEAR! then WAVE 2/2" (wrong call
  in round 1). Correlate with the report's events or door x positions first.
- Round 2 = re-record the SAME route after fixes and review again at 1 fps around every
  callout: the round-2 pass caught a stale subtitle left by an overtaken banner slam that
  no round-1 frame could show.
- Identical bot runs for two characters (same frames, same score) mean identical stats —
  a design finding, not a bot bug.

## Fan-out (multi-agent rounds)
- Base branch first: commit prior work, do repo-wide chores (UIDs, docs) and any shared
  signal CONTRACT before creating worktrees, so agents never edit the same lines.
- Worktrees at `C:/Users/gotmi/wt-<name>` (OneDrive paths are too long). Each runs
  `--import` first; a fresh 4.7 import rewrites committed `.import` files — never stage them.
- Agents may be blocked from `git merge` (classifier). The orchestrator merges each branch
  into the base, resolves `log.md` (keep both entries), reruns all suites per merge.
- Balance pass LAST, off the merged base: presentation timing changes fight length.

- Round 3 again faked a "doubled sign" (AtomicRobot TattoRobot) across adjacent tiles:
  a 5 fps strip of that second settles it in one image.
- Fighter sweep: `python tools/autoplay_sweep.py --base test/autoplay/completionist_mortal.json
  --chars Cody,Ryan,Cass,Caitlyn,Sara --seeds 1,2,3,4` (~3 min) — the balance card's table.

## 4. Artifact
Video + poster as published `files`, `downloads` capability for the MP4 button,
`db` collection `decisions/<id>` = {status: approved|later|rejected, note}. Read the
user's picks back with ArtifactData `list decisions`. Copy an older round's video into a new
page server-side with `files: {"r2.mp4": {artifact: <old url>, path: "after.mp4"}}`.
