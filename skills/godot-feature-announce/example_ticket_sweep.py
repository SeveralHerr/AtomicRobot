OUT = "ticket_sweep"
RAW = "raw.mp4"
GAME_Y = 380
SEGS = [
    {"src": (44.9, 46.5), "x": 640, "cw": 960, "zoom": 0.08},                                  # banner + first hit
    {"src": (38.0, 39.8), "x": 860, "cw": 700, "cy": 300, "ch": 480},                         # arch: cars parked below it
    {"src": (46.9, 48.4), "x": 1040, "cw": 480, "cy": 200, "ch": 400},                         # maid writing over the roof
    {"src": (48.80, 48.98), "x": 680, "cw": 640, "cy": 160, "ch": 560, "speed": 0.5, "zoom": 0.08},  # the swing, slowed
    {"src": (48.98, 49.30), "x": 680, "cw": 640, "cy": 160, "ch": 560, "freeze": 0.35},               # KO at speed, freeze on the clean burst
    {"src": (50.2, 50.95), "x": 1040, "cw": 480, "cy": 200, "ch": 400},                        # TICKET!
    {"src": (53.1, 55.0), "x": 760, "cw": 960, "zoom": 0.06},                                 # CARS SAVED
    {"src": (1.6, 2.9), "full": True, "cw": 1280, "y": 600, "freeze": 0.4},                   # title CTA
]
_d = [(b - a) / s.get("speed", 1.0) + s.get("freeze", 0) for s in SEGS for a, b in [s["src"]]]
T = [sum(_d[:i]) for i in range(len(_d) + 1)]
TEXTS = [
    {"t": (T[0], T[1]), "text": "NEW IN ATOMIC ROBOT", "size": 66, "y": 190, "color": "white", "anim": "none"},
    {"t": (T[0], T[1]), "text": "SIDE JOBS!", "size": 140, "y": 305, "anim": "none"},
    {"t": (T[1], T[2]), "text": "CUSTOMERS PARKED", "size": 66, "y": 190, "color": "white"},
    {"t": (T[1] + 0.1, T[2]), "text": "UNDER THE ARCH", "size": 120, "y": 300},
    {"t": (T[2], T[3]), "text": "THE MAIDS WANT", "size": 66, "y": 190, "color": "white"},
    {"t": (T[2] + 0.1, T[3]), "text": "TO TICKET THEM", "size": 120, "y": 300},
    {"t": (T[2] + 0.4, T[3]), "text": "WATCH THE SLIP FILL UP", "size": 56, "y": 1385, "color": "white"},
    {"t": (T[3], T[5]), "text": "KNOCK 'EM OFF", "size": 120, "y": 280},
    {"t": (T[4], T[5]), "text": "TWO AT ONCE!", "size": 56, "y": 1385, "color": "white"},
    {"t": (T[5], T[6]), "text": "TOO SLOW?", "size": 66, "y": 190, "color": "white"},
    {"t": (T[5] + 0.1, T[6]), "text": "NO BONUS FOR THAT CAR", "size": 92, "y": 300, "color": "0xff6a4d"},
    {"t": (T[6], T[7]), "text": "SAVE THE CARS", "size": 120, "y": 280},
    {"t": (T[6] + 0.2, T[7]), "text": "BONUS POINTS + A HEART", "size": 60, "y": 1400, "color": "white"},
    {"t": (T[7], T[8]), "text": "PLAY FREE", "size": 150, "y": 330, "anim": "slam"},
    {"t": (T[7] + 0.3, T[8]), "text": "ATOMIC ROBOT ON ITCH.IO", "size": 76, "y": 470, "color": "white"},
    {"t": (T[7], T[8]), "text": "PLAYS ON YOUR PHONE TOO", "size": 52, "y": 1390, "color": "white"},
]
FLASH = []
