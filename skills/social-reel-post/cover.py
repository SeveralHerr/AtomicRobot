"""Cover/thumbnail for the select+intro reel. python cover.py <frame.png> <out.png> [crop_dy]"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

W, H = 1080, 1920
FONT = "bangers.ttf"
YEL, CYAN = (255, 228, 0), (79, 227, 255)
CROP = (30, 532, 1050, 1048)            # hero + card + roster, no in-game title / EXIT GAME
SECRET = (833, 897, 957, 1035)          # ??? tile in source-frame coords
TILT = 2.0                              # degrees, comic-panel lean
GY = 780                                # top of game band on the cover


def text(d, xy, s, size, fill, stroke=10):
    f = ImageFont.truetype(FONT, size)
    d.text(xy, s, font=f, fill=fill, stroke_width=stroke, stroke_fill="black", anchor="mm")


def burst(img, centre, rays=18, r=900):
    """Comic sunburst like the select screen's, soft so the headline stays on top."""
    import math
    lay = Image.new("RGBA", img.size)
    d = ImageDraw.Draw(lay)
    cx, cy = centre
    for i in range(rays):
        a0 = 2 * math.pi * i / rays
        a1 = a0 + math.pi / rays
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)),
                   (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=(255, 200, 60, 52))
    mask = Image.new("L", img.size)
    ImageDraw.Draw(mask).ellipse((cx - 560, cy - 460, cx + 560, cy + 460), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(120))
    lay.putalpha(Image.composite(lay.getchannel("A"), Image.new("L", img.size), mask))
    img.paste(lay, (0, 0), lay)


def vignette(img, top=1340, alpha=225):
    """Fade the blurred bottom to near-black so nothing competes with the subline."""
    g = Image.new("L", (1, H))
    for y in range(H):
        g.putpixel((0, y), 0 if y < top else min(alpha, int(alpha * (y - top) / 200)))
    shade = Image.new("RGBA", (W, H), (10, 4, 8, 255))
    shade.putalpha(g.resize((W, H)))
    img.paste(shade, (0, 0), shade)


def split(d, y, parts, size, stroke):
    """One centred line drawn in several colours."""
    f = ImageFont.truetype(FONT, size)
    x = (W - sum(d.textlength(p, font=f) for p, _ in parts)) / 2
    for p, col in parts:
        d.text((x, y), p, font=f, fill=col, stroke_width=stroke, stroke_fill="black", anchor="lm")
        x += d.textlength(p, font=f)


def panel(game, k):
    """Game band as a tilted comic panel; the secret tile ring is drawn before the tilt."""
    g = game.convert("RGBA")
    x0, y0, x1, y1 = SECRET
    box = (round((x0 - CROP[0]) * k), round((y0 - CROP[1]) * k), round((x1 - CROP[0]) * k), round((y1 - CROP[1]) * k))
    ring = Image.new("RGBA", g.size)
    ImageDraw.Draw(ring).rounded_rectangle(box, 14, outline=CYAN + (255,), width=16)
    ring = ring.filter(ImageFilter.GaussianBlur(10))
    g.alpha_composite(ring)
    ImageDraw.Draw(g).rounded_rectangle(box, 14, outline=CYAN, width=6)
    b = 10
    framed = Image.new("RGBA", (g.width - 60 + 2 * b, g.height + 2 * b), "white")
    framed.paste(g.crop((30, 0, g.width - 30, g.height)), (b, b))
    ImageDraw.Draw(framed).rectangle((0, 0, framed.width - 1, framed.height - 1), outline="black", width=4)
    return framed.rotate(TILT, resample=Image.BICUBIC, expand=True)


def headline(c):
    lay = Image.new("RGBA", (W, 420))
    d = ImageDraw.Draw(lay)
    text(d, (W // 2, 110), "PICK YOUR", 190, YEL, 14)
    text(d, (W // 2, 285), "FIGHTER", 230, YEL, 16)
    lay = lay.rotate(-TILT * 1.6, resample=Image.BICUBIC)
    c.paste(lay, (0, 405), lay)


def main(src, out, dy=0):
    global CROP, SECRET
    dy = int(dy)                        # frames mid-zoom sit lower; shift the band crop
    CROP = (CROP[0], CROP[1] + dy, CROP[2], CROP[3] + dy)
    SECRET = (SECRET[0], SECRET[1] + dy, SECRET[2], SECRET[3] + dy)
    fr = Image.open(src).convert("RGB")
    game = fr.crop(CROP)
    k = W / game.width
    game = game.resize((W, round(game.height * k)), Image.LANCZOS)
    bg = game.resize((round(H * game.width / game.height), H)).crop((0, 0, W, H))
    c = bg.filter(ImageFilter.GaussianBlur(40))
    c = ImageEnhance.Brightness(ImageEnhance.Color(c).enhance(1.6)).enhance(0.55).convert("RGBA")
    burst(c, (W // 2, 600))
    vignette(c)
    p = panel(game, k)
    sh = Image.new("RGBA", p.size, (0, 0, 0, 0))
    sh.putalpha(p.getchannel("A").point(lambda a: a * 170 // 255))
    px = (W - p.width) // 2
    c.alpha_composite(sh, (px + 10, GY + 20))
    c.alpha_composite(p, (px, GY))
    headline(c)
    d = ImageDraw.Draw(c)
    split(d, GY + p.height + 95, [("5 FIGHTERS ", "white"), ("+1 SECRET", CYAN)], 112, 11)
    c.convert("RGB").save(out)


if __name__ == "__main__":
    main(*sys.argv[1:4])
