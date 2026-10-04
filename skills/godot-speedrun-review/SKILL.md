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
- Artifact publish cap 15 MB: two-pass `-b:v 520k`, 1024x640, 30 fps ≈ 14.8 MB for 3:15.

## 3. Review
- `fps=1/2` frames → PIL 4x4 sheets with a timecode label per tile. Read every sheet.
- Adjacent thumbnails can fake a bug (two tiles of one sign read as a doubled sign):
  re-extract the exact frame at full size before calling it a finding.
- Cross-check the report: `hurt` events by `near` (who hurts you), heal/powerup times,
  hp entering each scene, score before/after a scene change.
- One card per finding: timecode, what was seen, proposal, effort/impact.

## 4. Artifact
Video + poster as published `files`, `downloads` capability for the MP4 button,
`db` collection `decisions/<id>` = {status: approved|later|rejected, note}. Read the
user's picks back with ArtifactData `list decisions`.
