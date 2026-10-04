"""Shared ffmpeg helpers for the YouTube skills (Shorts + landscape video).
Imported by review_short.py and ../godot-youtube-video/*.py."""
import os, subprocess

FF = r"C:\Users\gotmi\AppData\Roaming\Python\Python310\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe"


def pop(a, F, kind="pop"):
    """fontsize expression for text that appears at time a with final size F."""
    d = "(t-%.3f)" % a
    if kind == "pop":   # grow 0->1.2F in 0.1s, settle to F by 0.2s
        return f"if(lt({d},0.1),{F}*max(0.05,{d}*12),if(lt({d},0.2),{F}*(1.2-({d}-0.1)*2),{F}))"
    if kind == "slam":  # huge -> F
        return f"if(lt({d},0.12),{F}*(2.5-{d}*12.5),{F})"
    return str(F)


def drawtext(tx, path, default_y=150):
    """One drawtext filter from a TEXTS entry. Text goes through textfile= (no escaping).
    Keys: t=(a,b) text size y color border box font anim(pop|slam|none|slide) x(px, left edge) ls(line spacing)."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    open(path, "w", encoding="utf-8").write(tx["text"])
    a, b = tx["t"]
    F, anim = tx.get("size", 90), tx.get("anim", "pop")
    y = tx.get("y", default_y)
    box = ":box=1:boxcolor=%s:boxborderw=18" % tx["box"] if tx.get("box") else ""
    if "x" in tx:  # left-anchored (lower thirds); "slide" eases in from the left edge
        x0 = tx["x"]
        x = (f"'if(lt(t-{a},0.25),-text_w+({x0}+text_w)*(1-pow(1-(t-{a})/0.25,3)),{x0})'"
             if anim == "slide" else str(x0))
    else:
        x = "(w-text_w)/2"
    size = pop(a, F, anim) if anim in ("pop", "slam") else str(F)
    return (f"drawtext=fontfile={tx.get('font', 'bangers.ttf')}:textfile={path}:fontsize='{size}'"
            f":fontcolor={tx.get('color', 'yellow')}:borderw={tx.get('border', 8)}:bordercolor=black"
            f":x={x}:y={y}-text_h/2:line_spacing={tx.get('ls', 8)}{box}:enable='between(t,{a},{b})'")


def flash(ft, dur=0.05, alpha=0.7):
    return f"drawbox=x=0:y=0:w=iw:h=ih:color=white@{alpha}:t=fill:enable='between(t,{ft},{ft + dur})'"


def encode(raw, fc, out, extra=()):
    """Run the filter graph (must end in [vo] and [ca]) to out.mp4. Returns stderr tail or ''."""
    cmd = [FF, "-y", "-loglevel", "error", "-i", raw, "-filter_complex", fc,
           "-map", "[vo]", "-map", "[ca]", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-color_range", "tv",
           "-crf", "20", "-preset", "medium", *extra,
           "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", out]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.stderr[-2000:] if r.returncode else ""


def frames(video, fps, d):
    """Extract frames at fps into folder d (emptied first); returns sorted paths."""
    import glob
    os.makedirs(d, exist_ok=True)
    for f in glob.glob(f"{d}/*.png"):
        os.remove(f)
    subprocess.run([FF, "-loglevel", "error", "-i", video, "-vf", f"fps={fps}", f"{d}/%03d.png"], check=True)
    return sorted(glob.glob(f"{d}/*.png"))
