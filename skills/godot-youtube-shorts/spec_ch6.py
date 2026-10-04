OUT = "ch6"
RAW = "raw_h.mp4"
GAME_Y = 360
FZ = 0.3
# name, start, KO time (event kill), end, colour
F = [("Cody", 2.6, 4.05, 5.0, "yellow"), ("Ryan", 3.0, 4.25, 5.4, "0x7fd1ff"), ("Cass", 3.0, 4.25, 5.4, "0xff5a3c"),
     ("Caitlyn", 6.8, 7.75, 9.2, "0xff9de1"), ("Sara", 3.2, 4.45, 5.6, "0x9dff7a")]
SEGS, TEXTS, FLASH, t = [], [], [], 0.0
for n, a, k, b, c in F:
    k += 0.12
    SEGS.append({"raw": f"chars/{n}.mp4", "src": (a, k), "x": 600, "cw": 640, "zoom": 0.12, "freeze": FZ})
    SEGS.append({"raw": f"chars/{n}.mp4", "src": (k, b), "x": 600, "cw": 640})
    d = b - a + FZ
    TEXTS.append({"t": (t, t + d), "text": n.upper(), "size": 130, "y": 275, "color": c, "anim": "slam"})
    FLASH += [t, t + k - a]
    t += d
A = t
SEGS += [{"src": (243.4, 248.8), "x": 600, "cw": 1040},
         {"src": (2.0, 2.1), "full": True, "cw": 1280, "freeze": 2.8, "y": 600}]
E = A + 5.4
TEXTS += [
    {"t": (0, A), "text": "5 PLAYABLE FIGHTERS", "size": 70, "y": 175, "color": "white", "anim": "none"},
    {"t": (A, E), "text": "STORY STOPS AT", "size": 80, "y": 180, "color": "white"},
    {"t": (A + 0.15, E), "text": "LOCAL LANDMARKS", "size": 124, "y": 275, "color": "0x4fe3ff"},
    {"t": (E, E + 2.9), "text": "PLAY FREE", "size": 150, "y": 330, "anim": "slam"},
    {"t": (E + 0.3, E + 2.9), "text": "ATOMIC ROBOT ON ITCH.IO", "size": 76, "y": 470, "color": "white"},
    {"t": (E, E + 2.9), "text": "PLAYS ON YOUR PHONE TOO", "size": 52, "y": 1390, "color": "white"},
]
FLASH = [f for f in FLASH[1:]] + [A, E]
FLASH = []
