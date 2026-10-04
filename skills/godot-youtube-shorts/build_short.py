"""Build a 1080x1920 YouTube Short from raw.mp4: python build.py spec_vN.py
Spec module defines SEGS, TEXTS, OUT. Run from this folder (font paths are relative)."""
import os, subprocess, sys, runpy

FF = r"C:\Users\gotmi\AppData\Roaming\Python\Python310\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe"
spec = runpy.run_path(sys.argv[1])
SEGS, TEXTS, OUT = spec["SEGS"], spec["TEXTS"], spec["OUT"]
GAME_Y = spec.get("GAME_Y", 380)
W, H = 1080, 1920

def pop(a, F, kind="pop"):
    d = "(t-%.3f)" % a
    if kind == "pop":   # grow 0->1.2F in 0.1s, settle to F by 0.2s
        return f"if(lt({d},0.1),{F}*max(0.05,{d}*12),if(lt({d},0.2),{F}*(1.2-({d}-0.1)*2),{F}))"
    if kind == "slam":  # huge -> F
        return f"if(lt({d},0.12),{F}*(2.5-{d}*12.5),{F})"
    return str(F)

parts, labels, t = [], [], 0.0
os.makedirs("txt", exist_ok=True)
for i, s in enumerate(SEGS):
    a, b = s["src"]
    speed = s.get("speed", 1.0)
    dur = (b - a) / speed
    cw = s.get("cw", 720)
    zoom = s.get("zoom", 0)  # punch-in at segment start: extra scale that decays
    if s.get("full"):  # whole frame, letterboxed (end card)
        fg = f"crop={s.get('cw', 1280)}:800,scale=1080:-2:flags=lanczos"
        gy = s.get("y", 600)
    else:
        fg = f"crop={cw}:800:{s['x'] - cw // 2}:0,scale=1080:{int(800 * 1080 / cw)}:flags=neighbor"
        gy = GAME_Y
    if zoom:
        fg += (f",scale=w='iw*(1+{zoom}*exp(-t*10))':h='ih*(1+{zoom}*exp(-t*10))':eval=frame"
               f",crop=1080:{int(800 * 1080 / cw)}")
    freeze = s.get("freeze", 0)
    tail = f",tpad=stop_mode=clone:stop_duration={freeze}" if freeze else ""
    parts.append(
        f"[0:v]trim={a}:{b},setpts=(PTS-STARTPTS)/{speed},split[s{i}a][s{i}b];"
        f"[s{i}a]scale=-2:{H},crop={W}:{H},boxblur=30:3,eq=brightness=-0.25[bg{i}];"
        f"[s{i}b]{fg}[fg{i}];[bg{i}][fg{i}]overlay=(W-w)/2:{gy},fps=60{tail},format=yuv420p,setsar=1[v{i}];")
    atempo = f",atempo={speed}" if speed != 1.0 else ""
    apad = f",apad=pad_dur={freeze}" if freeze else ""
    parts.append(f"[0:a]atrim={a}:{b},asetpts=PTS-STARTPTS{atempo}{apad}[a{i}];")
    labels.append(f"[v{i}][a{i}]")
    t += dur + freeze
total = t
fc = "".join(parts) + "".join(labels) + f"concat=n={len(SEGS)}:v=1:a=1[cv][ca];"
# flashes between cuts
v = "[cv]"
chain = []
for j, tx in enumerate(TEXTS):
    p = f"txt/{OUT}_{j}.txt"
    open(p, "w", encoding="utf-8").write(tx["text"])
    a, b = tx["t"]
    F = tx.get("size", 90)
    font = tx.get("font", "bangers.ttf")
    y = tx.get("y", 150)
    col = tx.get("color", "yellow")
    bw = tx.get("border", 8)
    box = ":box=1:boxcolor=%s:boxborderw=18" % tx["box"] if tx.get("box") else ""
    chain.append(
        f"drawtext=fontfile={font}:textfile={p}:fontsize='{pop(a, F, tx.get('anim', 'pop'))}'"
        f":fontcolor={col}:borderw={bw}:bordercolor=black:x=(w-text_w)/2:y={y}-text_h/2"
        f":line_spacing=8{box}:enable='between(t,{a},{b})'")
for ft in spec.get("FLASH", []):
    chain.append(f"drawbox=x=0:y=0:w=iw:h=ih:color=white@0.7:t=fill:enable='between(t,{ft},{ft + 0.05})'")
fc += "[cv]" + ",".join(chain) + "[vo]" if chain else "[cv]null[vo]"
cmd = [FF, "-y", "-loglevel", "error", "-i", spec.get("RAW", "raw.mp4"), "-filter_complex", fc,
       "-map", "[vo]", "-map", "[ca]", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-color_range", "tv", "-crf", "20", "-preset", "medium",
       "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", f"{OUT}.mp4"]
r = subprocess.run(cmd, capture_output=True, text=True)
print(r.stderr[-2000:] if r.returncode else f"ok {OUT}.mp4 {total:.1f}s")
