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
- Scenario: `boot` (cut scenes on), `menu 40`, **`crt off`** (user rejected CRT footage as
  "terrible": scanlines + bezel blur the art), `god on` (patched god takes real hits), `teleport` to just before the
  previous door so the route reaches the feature naturally, `brain advance` / `brain clear`.
- Try 3-4 seeds headless with `--events job,objective,kill,hurt`; record the one where the
  feature runs longest and something goes wrong once (a stake beat: here one car got TICKET!).
  Movie Maker time == game time: the recorded report's event `t` indexes the footage.

## 1b. If the footage can't show it, fix the feature
- User: "it doesn't show enough of the maids trying to ticket". The cause was in-game (writers
  drawn behind the car body), not the edit. Check the feature's own readability at 2x before
  cutting around it; fix + test + re-record (TICKET SWEEP! c9e8e34).

## 2. Clear clips first (user: "just show off clear video snippets of the feature")
- Every clip in ONE 1080x800 box at `GAME_Y = 560`, cropped at an exact integer scale:
  `cw 1080` (1x, wide: banners, a whole row) or `cw 540, ch 400` (2x, close: the action).
  No `zoom` punches and no other `cw` — non-integer scaling smears pixel art.
- As few cuts as possible (user: "too many clips, hard to follow"): a 1x hook shot, ONE
  continuous 2x shot of the whole feature (rule -> fight -> payoff), the CTA. Captions may change
  inside the shot (one per phase) — cuts are what lose the viewer, not captions.
- The game camera follows the player, so a fixed 2x crop clips bursts at both edges: give the
  shot `"pan": [(seg_t, x_centre), ...]` (build_short eases between keys with smoothstep).
  Read keys off a 4 fps grid of the shot; hold a key until a burst at the edge has faded.
- End each caption one frame before its cut (`t1 - 1/60`): build_short's cut lands a frame
  before the text's `between()` window closes. Start clips after the game's own banner/burst
  has text on it (an empty banner stripe or blank starburst reads as a glitch on frame 1).
- A cut-scene establishing shot is only worth it if the subject reads at 1x; otherwise caption
  the location instead.

## 2b. Shape (≈10 s, one idea per beat, captions top y 190/300)
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
- With the 1080x800 box at `GAME_Y = 560` the game ends at 1360; bottom labels at y ≤ 1400
  (the bottom zone starts at 1440).
- Right rail x > 900 (y 700-1440): an actor at source x `sx` lands at
  `(sx - (x - cw/2)) * 1080 / cw`. One ~100 px from the frame edge needs `cw ≤ 480` to land
  left of ~860 — zoom in rather than let the rail cover the beat.
- `slam` on a long caption clips its first frames: use `pop` unless the line is short.

## 4. Deliver
- Final encode for the artifact (15 MB file cap): `-b:v 8M -maxrate 9M -bufsize 16M`,
  audio `volume=-3dB,alimiter=limit=0.8` (-1.5 dB still peaked -0.3 after AAC; alimiter alone 0.0).
- Artifact: `<video controls playsinline poster>`, a Download button using the `downloads`
  capability (fetch the published file → Blob → `downloads.save({filename, data})` — NEVER pass
  `request`: it is only for answering a platform export token; with any other string every save
  was refused and the user couldn't download the MP4), chapter buttons that seek,
  suggested post copy with copy buttons, and a Post it? Approve/Later card in db `decisions`
  (posting itself follows `skills/social-reel-post`, only after the user says yes).
- Example spec: `example_ticket_sweep.py` (TICKET SWEEP! v3 — hook + one panned shot + CTA, 9.1 s; raw = seed 1 take, `crt off`).
