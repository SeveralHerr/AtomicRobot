"""Contact sheet of a 1920x1080 cut with YouTube safe zones drawn on every frame.
    python review_video.py v1 [fps=2] [end_start_s] [--at 3.2,10,31.5]
-> v1_sheet.png, plus full-size zone-marked frames rv_v1/at_<t>.png for each --at time.
Zones: yellow = title safe (90%), green = action safe (93%), red = player chrome
(top title bar on hover / bottom progress bar + controls), cyan = end-screen elements
(drawn only from end_start_s on; keep text and action OUT of them)."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot-youtube-shorts"))
from PIL import Image, ImageDraw  # noqa: E402
from ffx import FF, frames  # noqa: E402

W, H = 1920, 1080
# 2 video elements + subscribe circle; text goes above y 330 or in 760-950.
END_VIDEOS = [(160, 380, 800, 740), (1120, 380, 1760, 740)]
END_SUB = (960, 560, 110)


def mark(im, end=False):
    d = ImageDraw.Draw(im)
    d.rectangle((96, 54, W - 96, H - 54), outline="yellow", width=4)
    d.rectangle((67, 38, W - 67, H - 38), outline="lime", width=3)
    d.rectangle((0, 0, W, 100), outline="red", width=5)      # title/share bar on hover
    d.rectangle((0, 970, W, H), outline="red", width=5)      # progress bar + controls
    if end:
        for r in END_VIDEOS:
            d.rectangle(r, outline="cyan", width=6)
        x, y, r = END_SUB
        d.ellipse((x - r, y - r, x + r, y + r), outline="cyan", width=6)
    return im


def main(argv):
    at = []
    if "--at" in argv:
        k = argv.index("--at")
        at = [float(v) for v in argv[k + 1].split(",")]
        argv = argv[:k] + argv[k + 2:]
    name = argv[1]
    fps = float(argv[2]) if len(argv) > 2 else 2.0
    end_t = float(argv[3]) if len(argv) > 3 else 1e9
    fr = frames(f"{name}.mp4", fps, f"rv_{name}")
    tw, th, cols = 384, 216, 8
    sheet = Image.new("RGB", (cols * tw, ((len(fr) + cols - 1) // cols) * th), "black")
    for i, f in enumerate(fr):
        t = i / fps
        im = mark(Image.open(f).convert("RGB"), t >= end_t).resize((tw, th))
        ImageDraw.Draw(im).text((6, 4), f"{t:.1f}", fill="yellow")
        sheet.paste(im, ((i % cols) * tw, (i // cols) * th))
    sheet.save(f"{name}_sheet.png")
    import subprocess
    for t in at:
        p = f"rv_{name}/at_{t:g}.png"
        subprocess.run([FF, "-loglevel", "error", "-y", "-ss", str(t), "-i", f"{name}.mp4",
                        "-frames:v", "1", p], check=True)
        mark(Image.open(p).convert("RGB"), t >= end_t).save(p)
    print(len(fr), "frames ->", f"{name}_sheet.png", *(f"rv_{name}/at_{t:g}.png" for t in at))


if __name__ == "__main__":
    main(sys.argv)
