---
name: social-reel-post
description: Cut an extremely short (5-10 s) vertical highlight reel of Atomic Robot around ONE funny, cool or juicy moment, polish it through a 10-round validation loop, get the user's approval on a claude.ai artifact, then post it with claude-in-chrome to YouTube Shorts (Studio), Bluesky, TikTok Studio and Instagram Reels with a one-sentence caption, the itch.io + Instagram links and per-platform hashtags. Use whenever the user wants to post, upload, share, promote or advertise a clip/reel/short/TikTok of the game on social media, "put this on TikTok/Insta/Bluesky/YouTube", "make an ad clip", "cross-post the short", or a highlight/teaser for socials — even if they name only one platform.
---

# Highlight reel → 4 platforms

Pipeline: **pick beat → build → validate ×10 → captions → approval artifact → post → log**.
Nothing is posted before the user says yes in chat to the artifact. Never commit videos
(`autoplay_out/` is gitignored; work in `scratchpad/reel/`).

Constants (verify once per session; ask if any changed):
- itch: `https://severalherr.itch.io/atomic-robot`
- Instagram: `@atomicrobottattoo` / `https://www.instagram.com/atomicrobottattoo/`
- YouTube channel: `https://studio.youtube.com/channel/UCmtDiOdYrY3estK6ZCr5DfQ`
- Posting accounts (2026-10-05): YouTube "James Herr - Gamedev & Full Stack", Bluesky
  `jamesherr.bsky.social`, TikTok `@mrseveraljamcraft`, Instagram `@severaljamesherr`.
- Brand to tag: Instagram `@atomicrobottattoo` (robot-mascot avatar) — Tag people + caption mention.
  It has NO TikTok or Bluesky account found. TikTok `@robotatomicotattoo` and IG `@robot_atomico_tattoo`
  are "Robot Atomico Tattoo", a DIFFERENT shop — never tag them (tagged once by mistake, removed).

## 1. Pick ONE beat (extremely short = 5-10 s total)

An ad reel sells one idea. Footage, crop maths and beat timestamps come from
`skills/godot-youtube-shorts/SKILL.md` §1-2 (human-looking take, `raw_h.mp4`) — reuse an existing
take before recording a new one (`find ~/AppData/Local/Temp/claude -name "raw_h.mp4"` — old
session scratchpads hold `raw_h.mp4` + `bangers.ttf`; run build_short.py with that folder as cwd).
`example_reel.py` as-is builds the validated 5.2 s Atomic Rage reel (clip A, 2026-10-05) — a known-good
smoke test. ffmpeg is NOT on PATH: use the imageio_ffmpeg binary named `FF` in `build_short.py`.
Human-take beats (verified frame by frame): Rage SMACK 258.2, KOs 258.5/258.75/259.0, BONK 259.5,
white KO flash 259.70-260.0, WAVE CLEAR full 259.87; car hits Cody 54.45 and 57.78; Cody's slash
(NOT the car) KOs the maid at 58.57, white 58.60-58.67. Title screen is live raw 1.5-2.9, black after 3.0.

Score candidates (funny / cool / juicy) and pick the one that reads with the sound OFF:
- **Funny**: car hits a maid, player gets bonked, the cat secret, a whiff then a comeback.
- **Cool**: power-up kick-in (Atomic Rage 2x, Overclock), character roster, story cut scene.
- **Juicy**: combo into STREET CLEAR!, hit-stop + KO burst, door-wave crumble.

**Check who did what at 30 fps before writing a caption** (`fps=30,tile=6x3` on the 0.6 s around
the hit): an 8 fps grid made a sword KO look like a car hit and "IT HITS THEM TOO!" was false.

Shape (≈8 s): **hook 0-0.5 s** (open ON a hit or on the weird thing, never a walk-in) →
**payoff** (slow-mo 0.5 + 0.3 s freeze on the impact) → **1.5 s CTA** ("PLAY FREE / ATOMIC ROBOT
ON ITCH.IO"). Make the last frame cut cleanly back to the first — reels autoloop, and a loop
that reads as continuous gets rewatched.

Copy is an AD, not a narration (user, 2026-10-05): every line sells a feature — power-ups (Rage 2x damage,
Overclock speed, drop from KOs), combos, sword combat, pick your fighter. A gag sticker ("AGAIN?!") is fine
only when the headline still pitches the game. Offer 2 copy options per clip as rendered videos.

House rules (user-set, still apply): no boss KO / YOU WIN / Robot unlock spoilers, no white
flashes, soft feature-led copy, never "we/our shop" voice, footage must look human-played.

## 2. Build

Copy `example_reel.py` to `scratchpad/reel/spec_r1.py`, set beats, then from the shorts folder:
`python build_short.py <scratch>/spec_r1.py` (needs `raw*.mp4` + `bangers.ttf` beside it; see that
skill §3). Output 1080x1920.
- Vertical crop: `"cy": 100, "ch": 700` drops the sky so fighters' feet clear the TikTok/IG
  bottom 25% (GAME_Y 330). Game-text hooks use `anim: none` — a `slam` on frame 1 is a clipped giant word.
- Derive text cues from SEGS (see example_reel.py `T` list); build_short snaps src to the 60 fps grid
  and trims each segment to an exact frame count, so a cue at `T[i]` lands on the cut.
- Keep slow-mo and freezes off the game's white KO flash; freeze on the swing arc or the burst after it.
- A 1.4 s frozen title CTA reads dead: use live title footage `(1.6, 2.9)` + 0.3 freeze.

Then size it for upload — `file_upload` caps one call at **10 MB**:
`ffmpeg -i rN.mp4 -c:v libx264 -b:v 6M -maxrate 7M -bufsize 12M -c:a aac -b:a 128k -movflags +faststart rN_up.mp4`
(an 8 s clip lands ~6 MB).

## 3. Validation loop (10 rounds)

Each round: `python ../godot-youtube-shorts/review_short.py rN 4` (Shorts UI zones in red) +
`python review_keys.py rN t1 t2 t3 t4` (4 key frames at HALF size with the UNION of all four apps'
zones: top 0-150, bottom 1440+, right rail x>900 y700-1440). Check the cut with 6 frames at 60 fps
around the CTA start: a 3-frame text lag hid in every contact sheet. Write 3 improvements into
`scratchpad/reel/rounds.md`, focused on **presentation, ad appeal, juice**, apply, rebuild `rN+1`.

Ask each round: Would a stranger stop scrolling at frame 1? Is the joke/feature readable in 1 s
with no sound? Is text clear of the red zones on ALL four apps (TikTok/IG cover the bottom
~25% and the right rail too)? Is the HUD clipped? Does the loop seam jar?
Stop early only if two consecutive rounds find nothing — and say so.

## 3b. Cover / thumbnail

Frame 0 of a reel is usually a bad cover (mid-slam text, UI still animating in). Build a
dedicated 1080x1920 cover from a SETTLED frame: `python skills/social-reel-post/cover.py <frame.png>
<out.png> [crop_dy]` (needs `bangers.ttf` in cwd; CROP/SECRET constants are for the select screen —
re-measure for other beats; `crop_dy` shifts the band for frames caught mid-zoom).
Review with `cover_review.py <out.png>` → full cover with zones + IG/TikTok 3:4 grid tile + Shorts
shelf tile. Keep every word inside the 3:4 crop (y 240-1680); one headline + one subline max —
a third line is unreadable at tile size. Offer A/B covers on the artifact.
Cover control: TikTok + Instagram take an uploaded image; YouTube desktop Studio may only allow
frame picks for Shorts; Bluesky has none (first frame) — offer a 1-frame cover prepend for it.

## 4. Captions

`python skills/social-reel-post/captions.py "<one sentence>" "<alt text>"` writes
`captions.json` and prints every platform's text with length checks. One sentence, feature-led,
no shop voice. The script holds the per-platform hashtag sets and limits (Bluesky 300 chars is
the tight one). New copy needs user approval — that happens on the artifact.

## 5. Approval artifact (before ANY posting)

Publish one artifact (load `artifact-design` first): each candidate clip as a `files` entry
(`<video controls loop muted playsinline>`), and under it each platform's exact caption.
If offering variants, label them A/B/C. Then stop and ask in chat:
"Approve clip X + captions for YouTube / Bluesky / TikTok / Instagram?"
Only a clear yes naming the clip unlocks step 6; edits → back to 3 or 4.

## 6. Post with claude-in-chrome

Load `anthropic-skills:chrome-browser` (or `claude-in-chrome`) first; one ToolSearch for the core
tools + `file_upload`, `find`, `form_input`. New tab per platform. Per-platform click paths and
fields: `references/platforms.md`.

In Claude Code auto mode the classifier blocks the Visibility/Publish step (seen 2026-10-05 on
YouTube): upload + fill everything as a private draft, then hand the final click to the user or
ask them to allow it — never route around the denial.
YouTube desktop Studio DOES take an uploaded Shorts thumbnail (Details > Thumbnail > Upload file).
Auto mode judges EACH platform post as its own outward action: "upload"/"finish upload" cleared
only the YouTube post already in progress; Bluesky was then blocked. Before step 6, get one chat
line naming every platform ("post to YouTube, Bluesky, TikTok and Instagram") and quote it.
Tabs: never close the tab group's last tab (the group dies and new tabs land outside it) — reuse
one tab and `navigate` it to each platform in turn.
After a click that changes page state (YouTube "Public"), screenshots can time out on a busy
tab: confirm with `find` / `get_page_text` instead (e.g. find the shorts URL in "Video published").

Before ANY upload: `document.visibilityState` must be "visible". Chrome defers media loading in a tab
that has never been shown; TikTok + Instagram read the video's metadata client-side and hang on a
spinner forever (no network request). Ask the user to click the Claude tab-group window itself.
Before tagging a brand on a new platform, cross-check the candidate's avatar/name against the
brand's known account (IG search shows look-alike shops side by side).

Rules that keep this safe:
- Check the logged-in account on each site matches what the user expects; name it in chat.
- `file_upload` the `rN_up.mp4` into the page's `input[type=file]` via its ref — never click the
  picker (native dialog is invisible). If the path is rejected ("not shared with this session"),
  tell the user the file path and ask them to drag it in, then continue.
- Fill caption fields from `captions.json` verbatim. Screenshot the filled form and stop for the
  final Post/Publish/Share click only if anything differs from the approved artifact.
- One platform at a time; if one fails, report it and continue with the rest.
- Decline cookie/consent extras; never accept new terms or change account settings without asking.

## 7. Log

Append to `scratchpad/reel/posted.md` and report in chat: clip, platform, post URL, time.
Update the `youtube-shorts` memory with the winning beat + what the user liked/rejected.
