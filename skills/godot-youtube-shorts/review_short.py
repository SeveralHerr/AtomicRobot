"""python review.py v1 [fps] -> v1_sheet.png (Shorts UI zones in red)"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from ffx import frames  # noqa: E402
name = sys.argv[1]; fps = sys.argv[2] if len(sys.argv) > 2 else "2"
fr = frames(f"{name}.mp4", fps, f"rv_{name}")
tw, th = 216, 384; cols = 12
sheet = Image.new("RGB", (cols * tw, ((len(fr) + cols - 1) // cols) * th), "black")
for i, f in enumerate(fr):
    im = Image.open(f).convert("RGB"); dr = ImageDraw.Draw(im)
    dr.rectangle((0, 1560, 1080, 1920), outline="red", width=6)   # title/channel overlay
    dr.rectangle((940, 900, 1080, 1560), outline="red", width=6)  # like/comment buttons
    dr.rectangle((0, 0, 1080, 120), outline="red", width=6)       # top bar
    im = im.resize((tw, th)); ImageDraw.Draw(im).text((4, 4), f"{i / float(fps):.1f}", fill="yellow")
    sheet.paste(im, ((i % cols) * tw, (i // cols) * th))
sheet.save(f"{name}_sheet.png"); print(len(fr), "frames")
