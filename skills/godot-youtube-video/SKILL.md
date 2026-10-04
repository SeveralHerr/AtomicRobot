---
name: godot-youtube-video
description: Cut a normal landscape (16:9, 1920x1080) YouTube video of Atomic Robot from an autoplay recording: a trailer, gameplay highlight, devlog clip or any landscape upload. Covers the 16:10 to 16:9 crop, title/chapter cards, lower-third captions, punch-in/push zoom, slow-mo, freeze, cut flashes and a 5-20 s end screen, then a review against YouTube safe zones. Use for "trailer", "gameplay video", "highlight reel", "devlog video", "YouTube video" (not Shorts). For vertical clips use godot-youtube-shorts.
---

# Autoplay footage -> landscape YouTube video

Sibling of `skills/godot-youtube-shorts` (read its SKILL.md for the recording side).
Shared ffmpeg helpers (`FF`, `drawtext`, `flash`, `encode`, `frames`) live in
`../godot-youtube-shorts/ffx.py`; both skills import them, so a fix there helps both.
Outputs are NEVER committed: work in `scratchpad/<task>/`, deliver to `autoplay_out/videos/` (gitignored).

## 1. Footage
- Same take as Shorts: a detached worktree at HEAD with `git apply skills/godot-youtube-shorts/human_footage.patch`
  (worktree ONLY). The user rejects "perfect run" footage. Then `python tools/autoplay.py <scenario> --record raw.mp4`.
- Raw is 1280x800, 60 fps, with audio. Video time == game time, so report `kill`/`hurt`/`powerup`/`cutscene`/`scene`
  event `t` values index the footage. List them with a short python one-liner over `autoplay_out/<name>.json` events.
- Copy `bangers.ttf` (styles/Bangers-Regular.ttf) into the build folder. Font paths are relative.

## 2. Pick beats
- Gridded strips at 2-4 fps per candidate window (crop and scale with ffmpeg, paste with PIL). Note where the player is:
  the camera is not always centred (door-wave arenas lock it; jumps leave the frame at cw 960).
- Highlight order that worked (~38 s): cold open on a combo plus STREET CLEAR (3 s), title card (1.6 s), one beat per
  feature (combos, traffic with a slow-mo car hit, power-ups, door waves, lanes), the Arch cutscene card, boss intro
  (dialogue plus the game's FINAL BOSS banner plus 2 s of fight), then a 12 s end screen. Do NOT show the boss KO or WIN card.
- Good raw_h beats (seed 1): 40.6-43.6 combo; 215-218.2 17-hit combo; 54-55.2 and 57.2-58.6 car hits (57.83);
  273.3-274.6 overclock glow plus timer (cw 960 x 800 y 460); 235.3 rage triple KO; 223-224.6 WAVE 1/2;
  228-231 lanes; 244.4-246.6 Arch; 298.6-300.6 "parking on Sundays" line; 301.8-303.6 FINAL BOSS; 307.7-309.6 fight.

## 3. Build: `python build_video.py spec.py` (see `example_spec.py` for every key)
- Crop: 1280x800 is 16:10. Default window 1280x720 centred y 380 keeps the HP/score HUD and trims the road edge.
  cw 960 or 640 means crisp 2x or 3x nearest-neighbour; other widths use lanczos. Crops clamp to the frame.
- Boss room: cw 1120, x 720, y 425 drops the cutscene letterbox bars and keeps the speech bubble inside the frame.
- `card: True` gives blurred, dimmed footage as the background (title/chapter/end). `inset` adds a white-framed game window on top.
- TEXTS take `seg=i` (time relative to that segment) so retiming a cut never desyncs captions.
  Captions: top-left lower-third style (`x=120`, `anim="slide"`, `box="black@0.55"`, size 64, y 270).
- Cut flashes are automatic (`FLASH="cuts"`, alpha 0.5). `flash=False` on a segment that continues the same shot (slow-mo splits).
- The build ends with a 0.6 s fade out, video and audio together. A 38 s 1080p60 build takes about 25 s.

## 4. Review: `python review_video.py vN 2 <end_start> --at t1,t2,...`
- Sheet zones: yellow title-safe (90%), green action-safe (93%), red player chrome (top 0-100 hover bar,
  bottom 970-1080 progress bar), cyan end-screen elements (2 video boxes plus a subscribe circle) from `end_start` on.
- Then look at 4-6 `--at` frames FULL size. Thumbnails hid caption/HUD collisions and half-clipped scores.
- White tiles on the sheet that sit exactly on a cut time are the build's own 0.05 s cut flashes, sampled. Don't chase them.

## Copy rules (user)
- The user is NOT the tattoo shop: never "we/our shop". Soft, feature-led lines (setting, combos, traffic, power-ups,
  lanes, door waves, phone play). No taunts. Don't spoil the boss ending. CTA: "PLAY FREE" plus "ATOMIC ROBOT ON ITCH.IO".

## Lessons (2026-10-04, 7 builds)
- Top-left captions collide with the centred score and "N HITS!" text. Fix: size 64 or less (width under 700 px) plus a dark box.
- A title card from a dark or cutscene frame renders black. Blur a bright gameplay moment (dim -0.15).
- A power-up "pickup" is tiny on screen. What reads is the glow plus the HUD timer ("OVERCLOCK 6.2"). Punch in (cw 960) on that.
- A fixed-centre punch-in loses a player who runs or jumps. Re-centre x on the player per segment, and start after the game's banners leave.
- A tight y crop half-clips the score at the top edge. Either keep the whole HUD or crop it fully out.
- Boss dialogue reads in 2 s. 3 s of standing still sags. Cut the Arch card to about 2 s and add `push` for life.
- End-screen text: CTA above y 370, extra line around y 850. Both must stay clear of the cyan boxes and the red bars.
