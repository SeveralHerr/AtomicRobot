---

name: godot-youtube-shorts

description: Cut a 9:16 YouTube Short (~20 s) of Atomic Robot from an autoplay recording — crop, captions, punch-in zoom, slow-mo finisher, CTA end card — then review it against the Shorts UI safe zones. Use when asked for shorts/reels/TikToks, a vertical clip, or "a short video for social".

---

# Autoplay footage → YouTube Short



Outputs are NEVER committed: work in the session scratchpad, deliver to `autoplay_out/shorts/` (gitignored).



## 1. Footage (one take, many shorts)

- Detached worktree at HEAD (`C:/Users/gotmi/wt-shorts`, `--import` first) — the main checkout is often dirty with another session's WIP.

- Record a god-mode full run once: `python tools/autoplay.py <scratch>/short_robot.json --record <scratch>/raw.mp4` (~3.5 min wall, 211 MB). Scenario: `boot`, `menu 40`, `god on`, `brain advance 840`, `wait 5`. Robot is locked on a fresh save; the bot plays Cody (the shop's artist — good for the shop audience).

- Movie Maker video time == game time, so report `kill`/`powerup`/`cutscene` event `t` values index the video directly.



## 1b. Human-looking footage (required - user rejected "perfect run" footage)
- main's `god on` blocks every hit and the plain bot plays flawlessly. In the throwaway
  worktree ONLY: `git apply skills/godot-youtube-shorts/human_footage.patch` (from the main
  checkout path). It wires `human_style.gd` (from unmerged branch human-bot 26f17e9:
  combo -> retreat/strafe/hop/hesitate, flinch) into every brain decision, adds whiffed
  swings and late reactions, and makes god mode take real hits/knockback with HP floored at 1.
- Result (seed 1): 16 hits taken, car hits, boss drops HP to 1, rank B. Windowed take diverges
  from headless (one 2-min stall) - pick beats from the RECORDED report's events.
- Boss room camera drifts: crop it 900 wide from x 0 so the HP atoms stay in frame for a
  "1 HP LEFT!" sticker (hurt event hp == 1).

## 2. Pick moments

- Gridded strips (`drawgrid=w=160`) at 2 fps per candidate window; choose a crop centre x per segment. The camera is NOT always centred: door-wave arenas lock it, action sits at x≈1000.

- Good beats (seed 1, perfect bot - old): 40.55–43.9 combo → STREET CLEAR; 55–61.6 wave 2/2 → 18 hits; 170–178.2 boss phases → ADJOURNED; 181.6 YOU WIN card (earlier frames are still tuning in and show score "0").



## 3. Build

`python build_short.py spec.py` from a folder holding `raw.mp4`, `bangers.ttf` (styles/Bangers-Regular.ttf). See `example_spec.py`.

- Layout 1080x1920: blurred, darkened copy of the clip fills the frame; game crop (640 px wide → 1.69x, nearest-neighbour) at y 360; 2-line caption above (white setup line, big yellow/red punchline).

- Per segment: `zoom` (punch-in on the cut), `speed` (0.5 slow-mo, atempo keeps pitch), `freeze` (tpad after `fps`, or the frozen tail is dropped), `full` + `cw` for the end card.

- Text via `textfile=` (no escaping), `pop`/`slam` fontsize expressions; 0.05 s white flash on each cut.



## 4. Review (`python review_short.py vN 2`)

- Sheet with Shorts UI zones in red: top bar 0–120, buttons x>940 y 900–1560, caption y>1560. Keep text and action out of them.

- Then judge 4 key frames at half size — thumbnails hide clipped HUD and edge-cut fighters.

- Copy: the user is NOT the tattoo shop - never "we/our shop". Soft, feature-led lines (setting, combos, boss, phone play); no "X hates this guy" taunts.

- Lessons: open on a hit, not a walking player; put slow-mo on the hits, not on the game's white KO flash; check the HUD score isn't clipped at the crop edge; CTA must be concrete ("ATOMIC ROBOT ON ITCH.IO"), "link in bio" isn't clickable on Shorts.

