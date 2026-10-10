"""python rv.py A1 t1 t2 t3 t4 -> A1_keys.png: 4 key frames at HALF size, union of
YouTube/TikTok/IG/Bluesky UI zones in red (top 0-150, bottom 1440+, right rail x>900 y700-1440)."""
import sys, subprocess
from PIL import Image, ImageDraw
FF = r"C:\Users\gotmi\AppData\Roaming\Python\Python310\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe"
name, ts = sys.argv[1], [float(t) for t in sys.argv[2:]]
out = Image.new("RGB", (540 * len(ts), 960), "black")
for i, t in enumerate(ts):
    p = f"k_{name}_{i}.png"
    subprocess.run([FF, "-y", "-loglevel", "error", "-ss", str(t), "-i", f"{name}.mp4", "-frames:v", "1", p], check=True)
    im = Image.open(p).convert("RGB"); d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 1080, 150), outline="red", width=6)
    d.rectangle((0, 1440, 1080, 1920), outline="red", width=6)
    d.rectangle((900, 700, 1080, 1440), outline="red", width=6)
    d.text((10, 160), f"t={t}", fill="yellow")
    out.paste(im.resize((540, 960)), (540 * i, 0))
out.save(f"{name}_keys.png"); print("ok", f"{name}_keys.png")
