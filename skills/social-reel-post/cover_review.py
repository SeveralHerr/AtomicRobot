import sys
from PIL import Image, ImageDraw
src = sys.argv[1]; im = Image.open(src).convert("RGB"); z = im.copy(); d = ImageDraw.Draw(z)
d.rectangle((0, 240, 1079, 1680), outline="lime", width=4)
d.rectangle((0, 1440, 1079, 1919), outline="red", width=4)
d.rectangle((940, 900, 1079, 1700), outline="red", width=4)
grid = im.crop((0, 240, 1080, 1680)).resize((180, 240), Image.LANCZOS)   # IG/TikTok profile tile
shelf = im.resize((200, 356), Image.LANCZOS)                              # Shorts shelf tile
sheet = Image.new("RGB", (540 + 220, 960), (30, 30, 30))
sheet.paste(z.resize((540, 960)), (0, 0)); sheet.paste(grid, (560, 20)); sheet.paste(shelf, (550, 300))
sheet.save(src.replace(".png", "_review.png"))
