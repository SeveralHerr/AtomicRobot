OUT = "ticket_sweep"
RAW = "raw.mp4"
GAME_Y = 560
SEGS = [
    {"src": (42.45, 44.1), "x": 640, "cw": 1080},                              # TICKET SWEEP! banner over the parked row (1x)
    {"src": (44.3, 46.1), "x": 760, "cw": 540, "cy": 280, "ch": 400},       # the slip over the roof, the hit tears it (2x)
    {"src": (46.6, 48.0), "x": 580, "cw": 540, "cy": 280, "ch": 400},       # knocking them off (2x)
    {"src": (48.4, 50.05), "x": 640, "cw": 540, "cy": 250, "ch": 400},       # CARS SAVED! (2x)
    {"src": (1.6, 2.9), "full": True, "cw": 1280, "y": 600, "freeze": 0.4},  # title
]
_d = [(b - a) / s.get("speed", 1.0) + s.get("freeze", 0) for s in SEGS for a, b in [s["src"]]]
T = [sum(_d[:i]) for i in range(len(_d) + 1)]
TEXTS = [
    {"t": (T[0], T[1]), "text": "NEW SIDE JOB!", "size": 130, "y": 400, "anim": "none"},
    {"t": (T[0], T[1]), "text": "ATOMIC ROBOT", "size": 66, "y": 270, "color": "white", "anim": "none"},
    {"t": (T[0], T[1]), "text": "UNDER THE ARCH", "size": 60, "y": 1400, "color": "white", "anim": "none"},
    {"t": (T[1], T[2]), "text": "STOP THE TICKETS", "size": 120, "y": 400},
    {"t": (T[2], T[3]), "text": "KNOCK 'EM OFF THE CARS", "size": 96, "y": 400},
    {"t": (T[3], T[4]), "text": "SAVE ALL THREE", "size": 120, "y": 400},
    {"t": (T[4], T[5]), "text": "PLAY FREE", "size": 150, "y": 330, "anim": "slam"},
    {"t": (T[4] + 0.3, T[5]), "text": "ATOMIC ROBOT ON ITCH.IO", "size": 76, "y": 470, "color": "white"},
    {"t": (T[4], T[5]), "text": "PLAYS ON YOUR PHONE TOO", "size": 52, "y": 1390, "color": "white"},
]
# End every caption one frame before its cut: it lingered a frame over the next clip.
TEXTS = [dict(tx, t=(tx["t"][0], tx["t"][1] - (1 / 60 if tx["t"][1] < T[-1] - 0.01 else 0))) for tx in TEXTS]
FLASH = []
