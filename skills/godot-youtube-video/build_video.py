"""Build a 1920x1080 (16:9) YouTube video from a 1280x800 autoplay recording.
    python build_video.py spec.py        (run from a folder holding bangers.ttf)
Spec defines SEGS, TEXTS, OUT, RAW; optional FLASH (list of t, or "cuts"), FADE (s).
See example_spec.py for every key. Shared ffmpeg helpers live in ../godot-youtube-shorts/ffx.py."""
import os, sys, runpy
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot-youtube-shorts"))
from ffx import drawtext, flash, encode  # noqa: E402

W, H, SW, SH = 1920, 1080, 1280, 800


def crop_scale(s):
    """Crop a 16:9 window (cw wide, centred on x,y, clamped to the frame) and scale to 1080p.
    Integer factors (cw 640/960) use nearest-neighbour for crisp pixels, others lanczos."""
    cw = s.get("cw", SW)
    ch = int(cw * 9 / 16) // 2 * 2
    x0 = min(max(s.get("x", SW // 2) - cw // 2, 0), SW - cw)
    y0 = min(max(s.get("y", 380) - ch // 2, 0), SH - ch)  # 380: keeps HUD, trims road edge
    flags = "neighbor" if W % cw == 0 else "lanczos"
    return f"crop={cw}:{ch}:{x0}:{y0},scale={W}:{H}:flags={flags}"


def video_chain(i, s):
    """Filter chain for one segment -> label [v{i}]."""
    a, b = s["src"]
    sp = s.get("speed", 1.0)
    head = f"[0:v]trim={a}:{b},setpts=(PTS-STARTPTS)/{sp}"
    fg = crop_scale(s)
    z, push = s.get("zoom", 0), s.get("push", 0)  # zoom: punch-in on the cut (decays ~0.3 s)
    if z or push:                                  # push: slow linear zoom-in over the segment
        k = f"(1+{z}*exp(-t*10)+{push}*t/{(b - a) / sp:.3f})"
        fg += (f",scale=w='trunc(iw*{k}/2)*2':h='trunc(ih*{k}/2)*2'"
               f":eval=frame:flags=lanczos,crop={W}:{H}")
    fr = s.get("freeze", 0)
    tail = f",fps=60,tpad=stop_mode=clone:stop_duration={fr}" if fr else ",fps=60"
    if "inset" not in s and not s.get("card"):
        return f"{head},{fg}{tail},format=yuv420p,setsar=1[v{i}];"
    # card: blurred, darkened footage fills the frame; optional framed inset of the game
    blur = f"{crop_scale({})},boxblur=24:2,eq=brightness={s.get('dim', -0.3)}:saturation=0.7"
    if "inset" not in s:
        return f"{head},{blur}{tail},format=yuv420p,setsar=1[v{i}];"
    bg = f"[s{i}a]{blur}"
    iw = int(W * s["inset"]) // 2 * 2
    ix, iy = s.get("ix", "(W-w)/2"), s.get("iy", "(H-h)/2")
    return (f"{head},split[s{i}a][s{i}b];{bg}[bg{i}];"
            f"[s{i}b]{fg},scale={iw}:-2,pad=iw+16:ih+16:8:8:white[fg{i}];"
            f"[bg{i}][fg{i}]overlay={ix}:{iy}{tail},format=yuv420p,setsar=1[v{i}];")


def audio_chain(i, s):
    a, b = s["src"]
    sp, fr = s.get("speed", 1.0), s.get("freeze", 0)
    tempo = f",atempo={sp}" if sp != 1.0 else ""
    pad = f",apad=pad_dur={fr}" if fr else ""
    vol = f",volume={s['vol']}" if "vol" in s else ""
    return f"[0:a]atrim={a}:{b},asetpts=PTS-STARTPTS{tempo}{vol}{pad}[a{i}];"


def build(spec):
    segs, out = spec["SEGS"], spec["OUT"]
    starts, t = [], 0.0
    for s in segs:
        starts.append(t)
        t += (s["src"][1] - s["src"][0]) / s.get("speed", 1.0) + s.get("freeze", 0)
    total = t
    fc = "".join(video_chain(i, s) + audio_chain(i, s) for i, s in enumerate(segs))
    fc += "".join(f"[v{i}][a{i}]" for i in range(len(segs))) + f"concat=n={len(segs)}:v=1:a=1[cv][ca0];"
    chain = []
    for j, tx in enumerate(spec["TEXTS"]):
        if "seg" in tx:  # times relative to a segment's start in the OUTPUT timeline
            o = starts[tx["seg"]]
            tx = dict(tx, t=(tx["t"][0] + o, tx["t"][1] + o))
        chain.append(drawtext(tx, f"txt/{out}_{j}.txt", default_y=900))
    fl = spec.get("FLASH", "cuts")
    cuts = [st for st, s in zip(starts[1:], segs[1:]) if s.get("flash", True)]  # flash=False: same shot
    chain += [flash(f, alpha=spec.get("FLASH_ALPHA", 0.5)) for f in (cuts if fl == "cuts" else fl)]
    fade = spec.get("FADE", 0.6)
    chain += [f"fade=t=in:d=0.25", f"fade=t=out:st={total - fade:.3f}:d={fade}"]
    fc += "[cv]" + ",".join(chain) + "[vo];"
    fc += f"[ca0]afade=t=in:d=0.25,afade=t=out:st={total - fade:.3f}:d={fade}[ca]"
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    err = encode(spec.get("RAW", "raw.mp4"), fc, f"{out}.mp4", extra=("-r", "60"))
    print(err or f"ok {out}.mp4 {total:.1f}s  cuts at " + " ".join(f"{s:.1f}" for s in starts))
    return total, starts


if __name__ == "__main__":
    os.makedirs("txt", exist_ok=True)
    build(runpy.run_path(sys.argv[1]))
