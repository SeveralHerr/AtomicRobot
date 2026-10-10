OUT = "ticket_sweep"
RAW = "raw.mp4"
GAME_Y = 560
SEGS = [
    {"src": (42.45, 44.1), "x": 640, "cw": 1080},                              # TICKET SWEEP! over the parked row (1x)
    {"src": (44.3, 50.05), "cw": 540, "cy": 260, "ch": 400,                    # one continuous shot (2x), panning
     "pan": [(0.0, 680), (0.55, 680), (0.95, 800), (1.85, 800), (2.25, 560), (4.0, 560), (4.35, 660)]},
    {"src": (1.6, 2.9), "full": True, "cw": 1280, "y": 600, "freeze": 0.4},   # title
]
_d = [(b - a) / s.get("speed", 1.0) + s.get("freeze", 0) for s in SEGS for a, b in [s["src"]]]
T = [sum(_d[:i]) for i in range(len(_d) + 1)]
F = 1 / 60
TEXTS = [
    {"t": (T[0], T[1] - F), "text": "ATOMIC ROBOT", "size": 66, "y": 270, "color": "white", "anim": "none"},
    {"t": (T[0], T[1] - F), "text": "NEW SIDE JOB!", "size": 130, "y": 400, "anim": "none"},
    {"t": (T[0], T[1] - F), "text": "UNDER THE ARCH", "size": 60, "y": 1400, "color": "white", "anim": "none"},
    {"t": (T[1], T[1] + 4.0), "text": "STOP THE TICKETS", "size": 120, "y": 400},
    {"t": (T[1] + 4.0, T[2] - F), "text": "SAVE ALL THREE", "size": 120, "y": 400},
    {"t": (T[2], T[3]), "text": "PLAY FREE", "size": 150, "y": 330, "anim": "slam"},
    {"t": (T[2] + 0.3, T[3]), "text": "ATOMIC ROBOT ON ITCH.IO", "size": 76, "y": 470, "color": "white"},
    {"t": (T[2], T[3]), "text": "PLAYS ON YOUR PHONE TOO", "size": 52, "y": 1390, "color": "white"},
]
FLASH = []
