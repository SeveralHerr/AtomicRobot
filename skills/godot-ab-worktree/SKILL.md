---
name: godot-ab-worktree
description: Compare old vs new behaviour of Atomic Robot by running the same autoplay scenarios on HEAD (a throwaway git worktree) and on the working tree. Use when a fix needs before/after evidence, a bug report can't be reproduced on one seed, or a GIF/report must show what changed.
---
# A/B a change with a HEAD worktree

```bash
git worktree add -f C:/wt/ar-old HEAD          # short path OUTSIDE OneDrive
godot --headless --path C:/wt/ar-old --import  # once, or scenes load with stale UIDs
cp tools/autoplay/*.gd C:/wt/ar-old/tools/autoplay/   # only if you added bot verbs
for root in C:/wt/ar-old .; do (cd $root && python tools/autoplay.py my.json); done
git worktree remove --force C:/wt/ar-old
```

- Put scenario JSON in the scratchpad and pass the path. Loop seeds 1-4 per character:
  one seed rarely reproduces a rare stall.
- Copy only TOOLING (bot verbs) into the old tree, never the fix under test.
- A forced bad state (`sink DY`) must be checked in the OLD build first: if the old
  build doesn't hold that state (the maid falls through the world instead), a
  before/after built on it is misleading. Use a natural run instead.
- GIFs: `snap_every` frames are named `f<frame>`. Six full-frame panels with CRT noise
  run past 16MB. Use 4 panels at 320x200, a 48-colour shared palette and a median
  filter. That comes to about 10MB.
