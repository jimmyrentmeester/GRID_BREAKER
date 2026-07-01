#!/usr/bin/env python3
"""Marketing screenshots for v1.3 — new campaign/modifiers screens.

In : docs/screenshots/v1.3/{menu,campaign-chapters,modifiers,gameplay-endless}.png
Out: docs/screenshots/iphone-6.9/{01..04}.png          (plain, App Store upload)
     docs/screenshots/iphone-6.9-marketing/{01..04}.png (neon overlay, for review/social)
"""
from PIL import Image, ImageDraw, ImageFont
import os

BASE   = os.path.dirname(os.path.abspath(__file__))
SRC    = os.path.join(BASE, "..", "docs", "screenshots", "v1.3")
REPO   = os.path.join(BASE, "..", "docs", "screenshots")
HFONT  = "/System/Library/Fonts/Supplemental/Courier New Bold.ttf"
SFONT  = "/System/Library/Fonts/Supplemental/Courier New.ttf"

CYAN    = (90, 243, 255)
MAGENTA = (255, 80, 200)
GOLD    = (255, 210, 64)
BG      = (8, 10, 18)
GRID_C  = (30, 34, 52)

# (output-name, source-file, headline, subline, headline-color)
SHOTS = [
    ("01-menu",     "menu",             "JACK IN.",             "Pure reflex. No filler.",          CYAN),
    ("02-gameplay", "gameplay-endless", "CHAIN INTO FEVER.",    "×2 score · hazards clear",  CYAN),
    ("03-campaign", "campaign-chapters","16-CORE CAMPAIGN.",    "4 chapters · boss at each finale", GOLD),
    ("04-modifiers","modifiers",        "PUSH YOUR LIMITS.",    "Harder runs → more credits",   MAGENTA),
]

def load(tag):
    p = os.path.join(SRC, f"{tag}.png")
    assert os.path.exists(p), f"Missing: {p}"
    return Image.open(p).convert("RGB")

def letterspaced(draw, text, y, font, color, canvas_w):
    """Draw text centered with slight extra letter-spacing."""
    base_w = draw.textlength(text, font=font)
    n = max(1, len(text) - 1)
    extra = min(12, (canvas_w * 0.78 - base_w) / n) if n > 0 else 0
    total = base_w + extra * n
    x = (canvas_w - total) / 2
    for i, ch in enumerate(text):
        draw.text((x, y), ch, font=font, fill=color)
        cw = draw.textlength(ch, font=font)
        x += cw + (extra if i < n else 0)

def neon_shadow(draw, text, y, font, color, canvas_w, layers=3):
    """Draw text with a soft neon glow (multi-pass offset trick via Pillow)."""
    # Pillow doesn't support blur shadows natively; approximate with colored outlines
    base_w = draw.textlength(text, font=font)
    x = (canvas_w - base_w) / 2
    glow = tuple(min(255, int(c * 0.45)) for c in color)
    for ox in range(-layers, layers + 1):
        for oy in range(-layers, layers + 1):
            if ox == 0 and oy == 0:
                continue
            draw.text((x + ox, y + oy), text, font=font, fill=glow)
    draw.text((x, y), text, font=font, fill=color)

def marketing(shot, headline, subline, headline_color):
    W, H = 1320, 2868
    canvas = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(canvas)

    # grid backdrop
    for x in range(0, W, 110):
        d.line([(x, 0), (x, H)], fill=GRID_C, width=2)
    for y in range(0, H, 110):
        d.line([(0, y), (W, y)], fill=GRID_C, width=2)

    hfont = ImageFont.truetype(HFONT, 104)
    sfont = ImageFont.truetype(SFONT, 50)

    letterspaced(d, headline, 148, hfont, headline_color, W)
    sw = d.textlength(subline, font=sfont)
    neon_shadow(d, subline, 306, sfont, MAGENTA if headline_color != MAGENTA else CYAN, W)

    # rounded screenshot
    sw_, sh_ = 1082, 2351
    inner = shot.resize((sw_, sh_), Image.LANCZOS)
    mask = Image.new("L", (sw_, sh_), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw_ - 1, sh_ - 1], radius=84, fill=255)
    px, py = (W - sw_) // 2, 460
    canvas.paste(inner, (px, py), mask)

    # thin outline
    outline_color = tuple(min(255, int(c * 0.55)) for c in headline_color)
    ImageDraw.Draw(canvas).rounded_rectangle(
        [px - 2, py - 2, px + sw_ + 1, py + sh_ + 1],
        radius=86, outline=outline_color, width=3)

    return canvas

def main():
    for sub in ("iphone-6.9", "iphone-6.9-marketing"):
        os.makedirs(os.path.join(REPO, sub), exist_ok=True)

    thumbs_plain, thumbs_mkt = [], []
    for name, tag, headline, subline, color in SHOTS:
        plain = load(tag)
        assert plain.size == (1320, 2868), f"{tag}: {plain.size}"
        out_plain = os.path.join(REPO, "iphone-6.9", f"{name}.png")
        plain.save(out_plain)

        m = marketing(plain, headline, subline, color)
        out_mkt = os.path.join(REPO, "iphone-6.9-marketing", f"{name}.png")
        m.save(out_mkt)

        thumbs_plain.append(plain)
        thumbs_mkt.append(m)
        print(f"  {name}: plain + marketing")

    # contact sheet
    TW, TH = 264, 573
    sheet = Image.new("RGB", (TW * len(SHOTS), TH * 2 + 6), (0, 0, 0))
    for i, (p, mk) in enumerate(zip(thumbs_plain, thumbs_mkt)):
        sheet.paste(p.resize((TW, TH)), (i * TW, 0))
        sheet.paste(mk.resize((TW, TH)), (i * TW, TH + 6))
    sheet_path = "/tmp/v1.3_marketing_sheet.png"
    sheet.save(sheet_path)
    print(f"\nContact sheet: {sheet_path}")

if __name__ == "__main__":
    main()
