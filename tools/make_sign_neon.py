#!/usr/bin/env python3
"""Cut the shop sign's painted white outline out of Shop.png as two white masks:
shop_sign_tube.png (crisp, pixel-exact) and shop_sign_halo.png (blurred, PAD px
wider each side). scripts/morse_sign.gd tints and blinks them.

    python tools/make_sign_neon.py
"""
from pathlib import Path
from PIL import Image, ImageFilter

REPO = Path(__file__).resolve().parent.parent
BOX = (180, 5, 520, 75)   # sign lettering + atom inside images/new/Shop.png
PAD = 6
WHITE = 200               # outline pixels are near-white; brick tops out ~170

shop = Image.open(REPO / "images/new/Shop.png").convert("RGBA").crop(BOX)
mask = Image.new("L", shop.size, 0)
mask.putdata([255 if min(p[:3]) >= WHITE and p[3] else 0 for p in shop.getdata()])
tube = Image.new("RGBA", shop.size, (255, 255, 255, 0))
tube.putalpha(mask)
tube.save(REPO / "images/new/shop_sign_tube.png")

big = Image.new("L", (shop.width + 2 * PAD, shop.height + 2 * PAD), 0)
big.paste(mask, (PAD, PAD))
glow = big.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(2.5))
glow = glow.point(lambda v: min(255, v * 5 // 2))
# Glow only on the bricks: knock out the lettering itself (navy, red, white tube)
# so the additive halo never washes the letter fill out.
sign = Image.new("L", big.size, 0)
fill = Image.new("L", shop.size, 0)
fill.putdata([255 if (p[2] > p[0] + 20 or p[0] > 2.5 * p[1] or min(p[:3]) >= WHITE) else 0
              for p in shop.getdata()])
sign.paste(fill, (PAD, PAD))
glow = Image.composite(Image.new("L", big.size, 0), glow, sign)
halo = Image.new("RGBA", big.size, (255, 255, 255, 0))
halo.putalpha(glow)
halo.save(REPO / "images/new/shop_sign_halo.png")
print("tube", tube.size, "halo", halo.size, "lit px", sum(1 for v in mask.getdata() if v))
