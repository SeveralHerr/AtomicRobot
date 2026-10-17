"""Video -> timecode-labelled 4x4 contact sheets (review footage, not autoplay snaps).

    python tools/video_sheets.py video.mp4 outdir [step_s=2] [t0] [t1] [width=400]
"""
import subprocess, sys, pathlib, imageio_ffmpeg
from PIL import Image, ImageDraw

vid, out = sys.argv[1], pathlib.Path(sys.argv[2])
step = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0
t0 = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
t1 = float(sys.argv[5]) if len(sys.argv) > 5 else 99999.0
w = int(sys.argv[6]) if len(sys.argv) > 6 else 400
out.mkdir(parents=True, exist_ok=True)
fr = out / "fr"
fr.mkdir(exist_ok=True)
for f in fr.glob("*.jpg"):
    f.unlink()
ff = imageio_ffmpeg.get_ffmpeg_exe()
subprocess.run([ff, "-v", "error", "-ss", str(t0), "-i", vid, "-t", str(t1 - t0), "-vf", f"fps={1/step},scale={w}:-1",
                str(fr / "%05d.jpg")], check=True)
frames = sorted(fr.glob("*.jpg"))
COLS, ROWS = 4, 4
for s in range(0, len(frames), COLS * ROWS):
    chunk = frames[s:s + COLS * ROWS]
    im0 = Image.open(chunk[0])
    sheet = Image.new("RGB", (im0.width * COLS, im0.height * ROWS))
    for i, f in enumerate(chunk):
        im = Image.open(f).convert("RGB")
        t = t0 + (s + i) * step
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 58, 14), fill=(0, 0, 0))
        d.text((3, 2), f"{int(t//60)}:{t%60:05.2f}", fill=(255, 255, 0))
        sheet.paste(im, ((i % COLS) * im0.width, (i // COLS) * im0.height))
    p = out / f"sheet{s // (COLS*ROWS):02d}.jpg"
    sheet.save(p, quality=85)
    print(p)
