"""Draw the Mitra app icons (icons/*.png). Run from the repo root: python tools/make_icons.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path("icons")
OUT.mkdir(exist_ok=True)
BRAND = (15, 118, 110)     # --brand (teal)
CREAM = (255, 255, 255)


def malayalam_font(size):
    for name in ("Nirmala.ttc", "Nirmala.ttf", "kartika.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return None


def draw(size, maskable=False):
    img = Image.new("RGB", (size, size), BRAND if maskable else CREAM)
    d = ImageDraw.Draw(img)
    if not maskable:
        r = size * 0.22
        d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=BRAND)
    # "മി" (first letters of Mitra) in the middle; maskable icons keep it inside the safe zone.
    font = malayalam_font(int(size * (0.42 if maskable else 0.5)))
    text = "മി" if font else "M"
    font = font or ImageFont.load_default(size=int(size * 0.5))
    box = d.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    d.text(((size - w) / 2 - box[0], (size - h) / 2 - box[1]), text, font=font, fill=CREAM)
    return img


for s in (192, 512):
    draw(s).save(OUT / f"icon-{s}.png")
draw(512, maskable=True).save(OUT / "icon-maskable-512.png")
draw(180).save(OUT / "apple-touch-icon.png")
print("icons written to", OUT.resolve())
