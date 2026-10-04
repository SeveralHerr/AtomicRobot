OUT = "v10"
RAW = "raw_h.mp4"
GAME_Y = 360
SEGS = [
    {"src": (40.4, 44.0), "x": 600, "cw": 640, "zoom": 0.12},
    {"src": (53.9, 55.6), "x": 680, "cw": 640, "zoom": 0.12},
    {"src": (57.6, 59.0), "x": 680, "cw": 640, "zoom": 0.08},
    {"src": (322.0, 328.9), "x": 450, "cw": 900, "zoom": 0.12},
    {"src": (328.9, 329.8), "x": 450, "cw": 900, "speed": 0.5},
    {"src": (329.8, 331.2), "x": 640, "cw": 900},
    {"src": (334.5, 334.6), "full": True, "cw": 1120, "freeze": 2.8, "y": 560},
]
A, B = 3.6, 6.7
C = 16.8
TEXTS = [
    {"t": (0, A), "text": "AN ARCADE BEAT-EM-UP SET IN", "size": 66, "y": 180, "color": "white", "anim": "none"},
    {"t": (0, A), "text": "DOWNTOWN SIOUX FALLS", "size": 104, "y": 270, "anim": "slam"},
    {"t": (A, B), "text": "WATCH OUT", "size": 80, "y": 180, "color": "white"},
    {"t": (A + 0.15, B), "text": "FOR TRAFFIC", "size": 120, "y": 275},
    {"t": (B, C), "text": "FINAL BOSS", "size": 80, "y": 180, "color": "white"},
    {"t": (B + 0.15, C), "text": "CITY COUNCIL", "size": 124, "y": 275, "color": "0xff5a3c"},
    {"t": (8.8, 13.6), "text": "1 HP LEFT!", "size": 96, "y": 470, "color": "0xff5a3c", "anim": "slam"},
    {"t": (C, C + 2.9), "text": "PLAY FREE", "size": 150, "y": 300, "anim": "slam"},
    {"t": (C + 0.3, C + 2.9), "text": "ATOMIC ROBOT ON ITCH.IO", "size": 76, "y": 440, "color": "white"},
    {"t": (C, C + 2.9), "text": "PLAYS ON YOUR PHONE TOO", "size": 52, "y": 1390, "color": "white"},
]
FLASH = [A, B, C]
