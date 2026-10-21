#!/usr/bin/env python3
"""One-page post, 1080x1350, bright style: "Medical bill myths vs facts".

    python3 render_myths.py ../posts/infographic
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_appstore as A  # noqa: E402
import render_tips as T  # noqa: E402

W, H = 1080, 1350
PAIRS = [
    ("The bill is final.", "You can ask billing to review any charge."),
    ("The summary shows everything.", "The itemized bill shows every charge."),
    ("Insurance paid, so it's right.", "Errors happen. Check it against your EOB."),
    ("Only a lawyer can question it.", "Anyone can ask in writing, for free."),
]


def render(out):
    img = T.background()
    d = ImageDraw.Draw(img)
    cx = W / 2
    f = A.font(84, "Heavy")
    d.text((cx, 105), "Medical bill", font=f, fill=A.INK, anchor="mm")
    l2 = "myths vs. facts"
    w2 = d.textlength(l2, font=f)
    d.rounded_rectangle((cx - w2 / 2 - 24, 152, cx + w2 / 2 + 24, 244), radius=34, fill=A.LIME)
    d.text((cx, 198), l2, font=f, fill=A.INK, anchor="mm")

    y = 300
    mf, ff, lf = A.font(34, "Semibold"), A.font(38, "Bold"), A.font(24, "Heavy")
    for myth, fact in PAIRS:
        ch = 200
        card = A.card(W - 120, ch, radius=36)
        cd = ImageDraw.Draw(card)
        # myth row
        cd.rounded_rectangle((36, 30, 140, 66), radius=18, fill=(255, 228, 226))
        cd.text((88, 48), "MYTH", font=lf, fill=A.RED, anchor="mm")
        cd.text((166, 48), myth, font=mf, fill=(130, 136, 140), anchor="lm")
        tw = cd.textlength(myth, font=mf)
        cd.line((166, 50, 166 + tw, 50), fill=(150, 156, 160), width=3)
        # fact row
        cd.rounded_rectangle((36, 112, 140, 148), radius=18, fill=A.LIME_SOFT)
        cd.text((88, 130), "FACT", font=lf, fill=A.LIME_DEEP, anchor="mm")
        size = 38
        while cd.textlength(fact, font=A.font(size, "Bold")) > W - 120 - 166 - 36:
            size -= 1
        cd.text((166, 130), fact, font=A.font(size, "Bold"), fill=A.INK, anchor="lm")
        A.shadow_paste(img, card, 60, y, blur=16, offset=8, alpha=50)
        y += ch + 24

    d = ImageDraw.Draw(img)
    icon = Image.open(os.path.join(A.S, "devpost", "icon-1024.png")).convert("RGBA").resize((96, 96), Image.LANCZOS)
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 95, 95), radius=22, fill=255)
    fy = H - 140
    img.paste(icon, (70, fy), m)
    d.text((186, fy + 6), "Lime Shield checks your bill from a photo", font=A.font(34, "Bold"), fill=A.INK)
    d.text((186, fy + 52), "Free to try on the App Store · nothing leaves your phone",
           font=A.font(27, "Medium"), fill=A.SUB)

    os.makedirs(out, exist_ok=True)
    img.convert("RGB").save(os.path.join(out, "myths-vs-facts.png"))


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "infographic")
