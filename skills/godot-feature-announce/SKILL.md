---
name: godot-feature-announce
description: Make a ~10 s vertical "new feature" announcement reel (YouTube Shorts / TikTok / Reels) for an Atomic Robot feature that just shipped — human-looking footage of the feature on the shipped build, a hook → where → rule → answer → stakes → reward → CTA cut, safe-zone checks, and a downloadable delivery on a claude.ai artifact. Use when the user says "announce it like a new feature", "make a video/short/reel of the new X", "launch trailer", "feature teaser", or wants a clip right after merging/shipping something.
---
# Feature announcement reel

Builds on `skills/godot-youtube-shorts` (build_short.py, review_short.py, copy rules) and
`skills/social-reel-post` (review_keys.py, posting). This skill adds the SHAPE of an
announcement and the footage recipe for one specific feature. Never commit videos.

## 1. Footage on the shipped build
- Detached worktree at the shipped commit (`git worktree add --detach C:/Users/gotmi/wt-announce <sha>`),
  `--import`, then `git apply --3way <main>/skills/godot-youtube-shorts/human_footage.patch`
  (plain apply fails once Player.gd moved on; 3-way applies cleanly).
- Scenario: `boot` (cut scenes on — the feature's own reveal is often the best "where" shot),
  `menu 40`, `crt on`, `god on` (patched god takes real hits), `teleport` to just before the
  previous door so the route reaches the feature naturally, `brain advance` / `brain clear`.
- Try 3-4 seeds headless with `--events job,objective,kill,hurt`; record the one where the
  feature runs longest and something goes wrong once (a stake beat: here one car got TICKET!).
  Movie Maker time == game time: the recorded report's event `t` indexes the footage.

## 2. Shape (≈10 s, one idea per beat, captions top y 190/300)
| beat | ~s | content | rule learned |
|---|---|---|---|
| hook | 1.6 | in-game feature banner + first hit | caption says WHAT KIND ("NEW IN … / SIDE JOBS!"), never the feature name the banner already shows |
| where | 1.8 | establishing shot from the feature's cut scene | crop OFF the cut scene's title card; don't caption its title |
| rule | 1.5 | the enemy doing the thing (visual tell, e.g. the ticket slip) | a small bottom label points at the tell ("WATCH THE SLIP FILL UP") |
| answer | 1.0 | the player verb | slow-mo on the SWING only; play the white KO flash at speed; freeze 0.35 on the clean burst after it |
| stakes | 0.75 | what failure looks like | caption must match who did what (check at 30 fps) |
| reward | 1.9 | payoff burst + card stamp | say what you get ("BONUS POINTS + A HEART") |
| CTA | 1.7 | live title (raw 1.6-2.9) + freeze | "PLAY FREE / ATOMIC ROBOT ON ITCH.IO / PLAYS ON YOUR PHONE TOO" |

## 3. Safe zones (union of Shorts, TikTok, Reels — `review_keys.py` at half size)
- `GAME_Y = 380`; bottom labels at y ≤ 1385 (the bottom zone starts at 1440).
- Right rail x > 900 (y 700-1440): an actor at source x `sx` lands at
  `(sx - (x - cw/2)) * 1080 / cw`. One ~100 px from the frame edge needs `cw ≤ 480` to land
  left of ~860 — zoom in rather than let the rail cover the beat.
- `slam` on a long caption clips its first frames: use `pop` unless the line is short.

## 4. Deliver
- Final encode for the artifact (15 MB file cap): `-b:v 8M -maxrate 9M -bufsize 16M`,
  audio `volume=-1.5dB,alimiter=limit=0.85` (alimiter alone still peaked 0.0 dB after AAC).
- Artifact: `<video controls playsinline poster>`, a Download button using the `downloads`
  capability (fetch the published file → Blob → `downloads.save`), chapter buttons that seek,
  suggested post copy with copy buttons, and a Post it? Approve/Later card in db `decisions`
  (posting itself follows `skills/social-reel-post`, only after the user says yes).
- Example spec: `example_ticket_sweep.py` (TICKET SWEEP!, 2026-10-10, raw = seed 1 take).
