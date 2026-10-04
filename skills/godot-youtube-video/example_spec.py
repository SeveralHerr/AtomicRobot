"""~38 s landscape highlight (validated 2026-10-04 on raw_h, seed 1): python build_video.py example_spec.py
SEG keys: src=(a,b) raw secs | x,y crop centre (default 640,380) | cw crop width (1280 full; 960/640 = crisp 2x/3x)
  | zoom punch-in | push slow zoom | speed (0.5 slow-mo) | freeze secs | flash=False (same shot: no cut flash)
  | card (blurred bg) + dim | inset (framed game over the card) + ix/iy | vol
TEXT keys: seg=i makes t relative to that segment | x (left anchor) | anim pop/slam/slide/none | box | size y color"""
OUT = "highlight"
RAW = "raw_h.mp4"  # 1280x800 60 fps human-style take (see SKILL.md step 1)
SEGS = [
    {"src": (40.6, 43.6), "zoom": 0.1},                                     # 0 cold open: combo -> STREET CLEAR
    {"src": (41.9, 43.5), "card": True, "dim": -0.15},                      # 1 title card
    {"src": (215.0, 218.2), "zoom": 0.08},                                  # 2 combos
    {"src": (54.0, 55.2)},                                                  # 3 traffic
    {"src": (57.2, 57.7)},                                                  # 4
    {"src": (57.7, 58.2), "speed": 0.5, "flash": False},                    # 5 car hit slow-mo
    {"src": (58.2, 58.6), "flash": False},                                  # 6
    {"src": (273.3, 274.6), "cw": 960, "x": 800, "y": 460, "zoom": 0.08},   # 7 power-ups
    {"src": (234.8, 235.3)},                                                # 8 rage
    {"src": (235.3, 235.8), "speed": 0.5, "flash": False},                  # 9 rage triple KO slow-mo
    {"src": (223.0, 224.6)},                                                # 10 door wave
    {"src": (228.0, 231.0), "cw": 1152, "x": 740, "y": 400},                # 11 lanes
    {"src": (244.4, 246.6), "push": 0.08},                                  # 12 Arch card (game's own)
    {"src": (298.6, 300.6), "cw": 1120, "x": 720, "y": 425},                # 13 boss dialogue
    {"src": (301.8, 303.6), "cw": 1120, "x": 720, "y": 425},                # 14 FINAL BOSS banner
    {"src": (307.7, 309.6), "y": 400, "zoom": 0.08},                        # 15 fight
    {"src": (306.0, 306.1), "card": True, "freeze": 12},                    # 16 end screen
]
L = {"x": 120, "anim": "slide", "box": "black@0.55"}  # top-left lower-third style caption
TEXTS = [
    dict(L, seg=0, t=(0.2, 3.0), text="AN ARCADE BEAT-'EM-UP", size=44, y=190, color="white"),
    dict(L, seg=0, t=(0.35, 3.0), text="SET IN DOWNTOWN SIOUX FALLS", size=64, y=270),
    dict(seg=1, t=(0, 1.6), text="ATOMIC ROBOT", size=220, y=470, anim="slam"),
    dict(seg=1, t=(0.25, 1.6), text="A PIXEL-ART STREET BRAWLER", size=60, y=640, color="white", anim="none"),
    dict(L, seg=2, t=(0.1, 3.2), text="CHAIN BIG COMBOS", size=64, y=270),
    dict(L, seg=3, t=(0.1, 1.2), text="WATCH THE TRAFFIC", size=64, y=270),
    dict(L, seg=4, t=(0, 1.9), text="WATCH THE TRAFFIC", size=64, y=270, anim="none"),
    dict(L, seg=7, t=(0.05, 1.3), text="GRAB POWER-UPS", size=64, y=270),
    dict(L, seg=8, t=(0, 1.5), text="GRAB POWER-UPS", size=64, y=270, anim="none"),
    dict(L, seg=10, t=(0.1, 1.6), text="SURVIVE DOOR WAVES", size=64, y=270),
    dict(L, seg=11, t=(0.1, 3.0), text="BRAWL ACROSS THREE LANES", size=64, y=270),
    dict(L, seg=13, t=(0.15, 2.0), text="TAKE ON CITY HALL", size=64, y=270),
    dict(seg=16, t=(0.2, 12), text="PLAY FREE", size=170, y=205, anim="slam"),
    dict(seg=16, t=(0.5, 12), text="ATOMIC ROBOT ON ITCH.IO", size=84, y=330, color="white"),
    dict(seg=16, t=(0.8, 12), text="PLAYS ON YOUR PHONE TOO", size=56, y=850, color="white"),
]
