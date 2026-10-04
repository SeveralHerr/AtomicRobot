OUT = "v12"
RAW = "raw_h.mp4"
GAME_Y = 360
SEGS = [
    {"src": (40.4, 44.0), "x": 600, "cw": 640, "zoom": 0.12},
    {"src": (53.9, 55.6), "x": 680, "cw": 640, "zoom": 0.12},
    {"src": (57.6, 59.0), "x": 680, "cw": 640, "zoom": 0.08},
    {"src": (257.6, 260.4), "x": 720, "cw": 640, "zoom": 0.12},
    {"src": (273.8, 278.0), "x": 860, "cw": 720, "zoom": 0.12},
    {"src": (2.0, 2.1), "full": True, "cw": 1280, "freeze": 2.8, "y": 600},
]
A, B, R, O = 3.6, 6.7, 9.5, 13.7
TEXTS = [
    {"t": (0, A), "text": "AN ARCADE BEAT-EM-UP SET IN", "size": 66, "y": 180, "color": "white", "anim": "none"},
    {"t": (0, A), "text": "DOWNTOWN SIOUX FALLS", "size": 104, "y": 270, "anim": "slam"},
    {"t": (A, B), "text": "WATCH OUT", "size": 80, "y": 180, "color": "white"},
    {"t": (A + 0.15, B), "text": "FOR TRAFFIC", "size": 120, "y": 275},
    {"t": (B, R), "text": "DOUBLE DAMAGE", "size": 80, "y": 180, "color": "white"},
    {"t": (B + 0.15, R), "text": "ATOMIC RAGE", "size": 124, "y": 275, "color": "0xff5a3c"},
    {"t": (R, O), "text": "SPEED BOOST", "size": 80, "y": 180, "color": "white"},
    {"t": (R + 0.15, O), "text": "OVERCLOCK", "size": 124, "y": 275, "color": "0x4fe3ff"},
    {"t": (O, O + 2.9), "text": "PLAY FREE", "size": 150, "y": 330, "anim": "slam"},
    {"t": (O + 0.3, O + 2.9), "text": "ATOMIC ROBOT ON ITCH.IO", "size": 76, "y": 470, "color": "white"},
    {"t": (O, O + 2.9), "text": "PLAYS ON YOUR PHONE TOO", "size": 52, "y": 1390, "color": "white"},
]
FLASH = [A, B, R, O]
