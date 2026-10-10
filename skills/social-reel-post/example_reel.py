# ~5 s reel for ../godot-youtube-shorts/build_short.py (human take raw_h.mp4), validated 10 rounds 2026-10-05.
# One beat: Atomic Rage SMACK -> slow-mo KOs -> WAVE CLEAR freeze -> live title CTA. Text cues derive from SEGS.
OUT = "r1"
RAW = "raw_h.mp4"
GAME_Y = 330
K = {"cw": 640, "cy": 100, "ch": 700}
SEGS = [
    {"src": (258.15, 258.45), "x": 740, "zoom": 0.08, **K},
    {"src": (258.45, 259.1), "x": 740, "speed": 0.5, **K},
    {"src": (259.1, 260.0), "x": 760, **K},
    {"src": (260.0, 260.4), "x": 760, "speed": 0.5, "freeze": 0.3, "cw": 760, "cy": 100, "ch": 700},
    {"src": (1.6, 2.9), "full": True, "cw": 1280, "freeze": 0.3, "y": 600},
]
T = [0.0]
for s_ in SEGS:
    T.append(T[-1] + (round(s_["src"][1] * 60) - round(s_["src"][0] * 60)) / 60 / s_.get("speed", 1.0) + s_.get("freeze", 0))
C, M = T[4], 1 / 60
TEXTS = [
    {"t": (0, C - M), "text": "DOUBLE DAMAGE", "size": 72, "y": 185, "color": "white", "anim": "none"},
    {"t": (0, C - M), "text": "ATOMIC RAGE", "size": 124, "y": 270, "color": "0xff5a3c", "anim": "none"},
    {"t": (C, C + 1.6), "text": "PLAY FREE", "size": 150, "y": 330, "anim": "slam"},
    {"t": (C + 0.2, C + 1.6), "text": "ATOMIC ROBOT ON ITCH.IO", "size": 76, "y": 470, "color": "white"},
    {"t": (C + 0.4, C + 1.6), "text": "PLAYS IN YOUR BROWSER", "size": 70, "y": 1350, "color": "white"},
]
FLASH = []
