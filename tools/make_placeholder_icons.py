#!/usr/bin/env python3
"""Draws the placeholder item icons into art/icons (380x380 RGBA, transparent background)."""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 380
SS = 4  # drawn at SS times the size and downscaled for smooth edges
OUT_DIR = Path(__file__).resolve().parent.parent / "art" / "icons"
OUTLINE = (40, 34, 30, 255)


def s(v):
    return v * SS


def pts(points):
    return [(s(x), s(y)) for x, y in points]


def canvas():
    return Image.new("RGBA", (s(SIZE), s(SIZE)), (0, 0, 0, 0))


def thick_line(p0, p1, width):
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    nx, ny = -dy / length * width / 2, dx / length * width / 2
    return [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]


def scrap():
    img = canvas()
    d = ImageDraw.Draw(img)
    pieces = [
        ([(70, 120), (130, 70), (190, 95), (176, 150), (120, 168), (84, 150)], (168, 124, 72)),
        ([(160, 160), (230, 128), (300, 150), (312, 210), (262, 246), (196, 226), (170, 196)], (138, 140, 146)),
        ([(92, 200), (150, 214), (176, 262), (134, 300), (78, 268)], (116, 80, 46)),
        ([(230, 240), (286, 236), (320, 276), (292, 320), (236, 308), (218, 272)], (104, 106, 112)),
        ([(268, 88), (316, 96), (330, 132), (298, 150), (262, 124)], (150, 108, 62)),
    ]
    for poly, (r, g, b) in pieces:
        d.polygon(pts(poly), fill=(r, g, b, 255), outline=OUTLINE, width=s(3))
        light = tuple(min(255, c + 60) for c in (r, g, b)) + (255,)
        d.line(pts(poly[:2]), fill=light, width=s(4))
    return img


def dust():
    img = canvas()
    glow = canvas()
    ImageDraw.Draw(glow).ellipse((s(70), s(190), s(310), s(330)), fill=(130, 70, 200, 170))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(s(14))))
    d = ImageDraw.Draw(img)
    d.ellipse((s(70), s(250), s(310), s(330)), fill=(74, 36, 104, 255))
    rng = random.Random(7)
    colours = [(158, 88, 220), (196, 140, 246), (226, 200, 255), (255, 255, 255)]
    for _ in range(90):
        x = min(300, max(80, rng.gauss(190, 58)))
        y = min(300, max(150, rng.gauss(225, 40)))
        r = rng.uniform(4, 11)
        star = [(x, y - r), (x + r * 0.25, y - r * 0.25), (x + r, y), (x + r * 0.25, y + r * 0.25),
                (x, y + r), (x - r * 0.25, y + r * 0.25), (x - r, y), (x - r * 0.25, y - r * 0.25)]
        d.polygon(pts(star), fill=rng.choice(colours))
    return img


def ingot():
    img = canvas()
    d = ImageDraw.Draw(img)
    top = [(60, 190), (100, 140), (346, 140), (306, 190)]
    front = [(60, 190), (306, 190), (306, 262), (60, 262)]
    side = [(306, 190), (346, 140), (346, 212), (306, 262)]
    d.polygon(pts(front), fill=(184, 192, 204, 255), outline=OUTLINE, width=s(4))
    for i, y in enumerate(range(192, 262, 2)):
        t = i / 34
        shade = int(218 - 70 * t)
        d.line(pts([(62, y), (304, y)]), fill=(shade, shade + 6, shade + 16, 255), width=s(2))
    d.polygon(pts(side), fill=(132, 140, 154, 255), outline=OUTLINE, width=s(4))
    d.polygon(pts(top), fill=(236, 240, 246, 255), outline=OUTLINE, width=s(4))
    return img


def core():
    img = canvas()
    gem = [(190, 52), (300, 150), (262, 320), (118, 320), (80, 150)]
    d = ImageDraw.Draw(img)
    d.polygon(pts(gem), fill=(34, 30, 52, 255), outline=(120, 110, 160, 255), width=s(4))
    facet = (84, 74, 120, 255)
    for line in [[(190, 52), (190, 320)], [(80, 150), (300, 150)], [(80, 150), (190, 320)], [(300, 150), (118, 320)]]:
        d.line(pts(line), fill=facet, width=s(2))
    glow = canvas()
    ImageDraw.Draw(glow).ellipse((s(140), s(140), s(240), s(240)), fill=(90, 210, 255, 220))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(s(16))))
    d = ImageDraw.Draw(img)
    d.ellipse((s(172), s(172), s(208), s(208)), fill=(200, 250, 255, 255))
    d.ellipse((s(182), s(182), s(198), s(198)), fill=(255, 255, 255, 255))
    return img


def forge_kit():
    img = canvas()
    d = ImageDraw.Draw(img)
    anvil = [(56, 160), (330, 160), (330, 186), (296, 200), (256, 200), (246, 226), (276, 246),
             (276, 276), (106, 276), (106, 246), (136, 226), (126, 200), (84, 200), (56, 186)]
    d.polygon(pts(anvil), fill=(80, 84, 94, 255), outline=(30, 32, 38, 255), width=s(4))
    d.polygon(pts([(56, 160), (330, 160), (330, 172), (56, 172)]), fill=(122, 128, 140, 255))
    grip, head_centre = (110, 180), (250, 62)
    d.line(pts([grip, head_centre]), fill=(124, 78, 40, 255), width=s(18))
    dx, dy = head_centre[0] - grip[0], head_centre[1] - grip[1]
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    head_ends = [(head_centre[0] + nx * 55, head_centre[1] + ny * 55),
                 (head_centre[0] - nx * 55, head_centre[1] - ny * 55)]
    d.polygon(pts(thick_line(head_ends[0], head_ends[1], 50)), fill=(150, 155, 165, 255),
              outline=(60, 60, 68, 255), width=s(3))
    return img


def stamp_mark(img):
    d = ImageDraw.Draw(img)
    box = (s(12), s(12), s(84), s(58))
    d.rounded_rectangle(box, radius=s(8), fill=(18, 18, 26, 230), outline=(230, 200, 120, 255), width=s(3))
    font = ImageFont.load_default(size=s(30))
    left, top, right, bottom = d.textbbox((0, 0), "EG", font=font)
    x = (box[0] + box[2]) / 2 - (left + right) / 2
    y = (box[1] + box[3]) / 2 - (top + bottom) / 2
    d.text((x, y), "EG", font=font, fill=(240, 220, 150, 255))


ICONS = {
    "EG_Item_Scrap": scrap,
    "EG_Item_Dust": dust,
    "EG_Item_Ingot": ingot,
    "EG_Item_Core": core,
    "EG_Item_ForgeKit": forge_kit,
}


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, draw in ICONS.items():
        img = draw()
        stamp_mark(img)
        small = img.convert("RGBa").resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")
        small.save(OUT_DIR / f"{name}.png", optimize=True)
        print(f"wrote {OUT_DIR / (name + '.png')}")


if __name__ == "__main__":
    main()
