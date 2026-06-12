#!/usr/bin/env python3
"""Rebuild the App Store screenshot sets (Run #74).

In : 5 chosen 1320x2868 Simulator saves
Out: docs/screenshots/{iphone-6.9, iphone-6.5, iphone-6.9-marketing, iphone-6.5-marketing}
Marketing style replicates the Run #69 set: dark grid backdrop, letterspaced cyan
headline + magenta subline, rounded-corner screenshot with a thin outline.
"""
from PIL import Image, ImageDraw, ImageFont
import os

PICK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "screenshots", "iphone-6.9")  # regenerate FROM the plain set
REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "screenshots")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

CYAN = (90, 243, 255)
MAGENTA = (255, 80, 200)
BG = (8, 10, 18)
GRID = (30, 34, 52)

SHOTS = [  # (output name, source time-tag, headline, subline)
    ("01-menu",      "01-menu", "JACK IN.",          "A pure neon reflex hack"),
    ("02-fever",     "02-fever", "CHAIN INTO FEVER",  "x2 score - hazards clear"),
    ("03-campaign",  "03-campaign", "10-CORE CAMPAIGN",  "A new trick each core"),
    ("04-cyberdeck", "04-cyberdeck", "UPGRADE YOUR DECK", "Spend the credits you earn"),
    ("05-cosmetics", "05-cosmetics", "MAKE IT YOURS",     "8 neon palettes & trails"),
]

def src(tag):
    import glob
    hits = glob.glob(f"{PICK}/*{tag}.png")
    assert hits, tag
    return Image.open(hits[0]).convert("RGB")

def letterspaced(draw, text, y, font, color, canvas_w, advance):
    total = advance * len(text) - (advance - draw.textlength(text[-1], font=font))
    x = (canvas_w - total) / 2
    for ch in text:
        draw.text((x, y), ch, font=font, fill=color)
        x += advance

def marketing(shot, headline, subline):
    W, H = 1320, 2868
    canvas = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(canvas)
    for x in range(0, W, 110):
        d.line([(x, 0), (x, H)], fill=GRID, width=2)
    for y in range(0, H, 110):
        d.line([(0, y), (W, y)], fill=GRID, width=2)

    hfont = ImageFont.truetype(FONT, 96)
    sfont = ImageFont.truetype(FONT, 44)
    letterspaced(d, headline, 150, hfont, CYAN, W, advance=min(74, 1240 // max(1, len(headline))))
    sw = d.textlength(subline, font=sfont)
    d.text(((W - sw) / 2, 296), subline, font=sfont, fill=MAGENTA)

    # rounded screenshot with thin outline
    sw_, sh_ = 1082, 2351
    inner = shot.resize((sw_, sh_), Image.LANCZOS)
    mask = Image.new("L", (sw_, sh_), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw_ - 1, sh_ - 1], radius=84, fill=255)
    px, py = (W - sw_) // 2, 452
    canvas.paste(inner, (px, py), mask)
    ImageDraw.Draw(canvas).rounded_rectangle(
        [px - 2, py - 2, px + sw_ + 1, py + sh_ + 1], radius=86,
        outline=(70, 160, 190), width=3)
    return canvas

def main():
    for sub in ("iphone-6.9", "iphone-6.5", "iphone-6.9-marketing", "iphone-6.5-marketing"):
        os.makedirs(f"{REPO}/{sub}", exist_ok=True)
    for name, tag, headline, subline in SHOTS:
        plain = src(tag)
        assert plain.size == (1320, 2868), plain.size
        plain.save(f"{REPO}/iphone-6.9/{name}.png")
        plain.resize((1242, 2688), Image.LANCZOS).save(f"{REPO}/iphone-6.5/{name}.png")
        m = marketing(plain, headline, subline)
        m.save(f"{REPO}/iphone-6.9-marketing/{name}.png")
        m.resize((1242, 2688), Image.LANCZOS).save(f"{REPO}/iphone-6.5-marketing/{name}.png")
        print("done", name)
    # contact sheet for review
    W = 200
    h = int(W * 2868 / 1320)
    sheet = Image.new("RGB", (W * 5, h * 2), "black")
    for i, (name, *_id) in enumerate(SHOTS):
        sheet.paste(Image.open(f"{REPO}/iphone-6.9/{name}.png").resize((W, h)), (i * W, 0))
        sheet.paste(Image.open(f"{REPO}/iphone-6.9-marketing/{name}.png").resize((W, h)), (i * W, h))
    sheet.save("/tmp/new_sets.jpg", quality=85)

if __name__ == "__main__":
    main()
