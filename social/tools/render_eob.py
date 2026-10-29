#!/usr/bin/env python3
"""One-page post, 1080x1350: "EOB vs bill" side by side, bright style.

    python3 render_eob.py ../posts/infographic
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_appstore as A  # noqa: E402
import render_tips as T  # noqa: E402

W, H = 1080, 1350
BLUE = (10, 132, 255)
BLUE_SOFT = (220, 236, 255)


def column(img, x, title, tag, tag_fill, tag_ink, from_who, points, stamp, stamp_col):
    cw, ch = 450, 700
    card = A.card(cw, ch, radius=40)
    d = ImageDraw.Draw(card)
    d.rounded_rectangle((30, 30, 30 + d.textlength(tag, font=A.font(26, "Heavy")) + 40, 76), radius=23, fill=tag_fill)
    d.text((50, 53), tag, font=A.font(26, "Heavy"), fill=tag_ink, anchor="lm")
    d.text((30, 100), title, font=A.font(46, "Heavy"), fill=A.INK)
    d.text((30, 165), from_who, font=A.font(28, "Semibold"), fill=A.SUB)
    # mini document
    d.rounded_rectangle((30, 220, cw - 30, 420), radius=16, fill=(246, 247, 245))
    for i, k in enumerate([0.7, 0.5, 0.62, 0.45]):
        d.rounded_rectangle((55, 250 + i * 38, 55 + (cw - 200) * k, 266 + i * 38), radius=8, fill=(214, 220, 214))
        d.rounded_rectangle((cw - 130, 250 + i * 38, cw - 55, 266 + i * 38), radius=8, fill=(214, 220, 214))
    sw = d.textlength(stamp, font=A.font(28, "Heavy")) + 36
    sx, sy = (cw - sw) / 2, 365
    d.rounded_rectangle((sx, sy, sx + sw, sy + 46), radius=10, outline=stamp_col, width=4)
    d.text((cw / 2, sy + 23), stamp, font=A.font(28, "Heavy"), fill=stamp_col, anchor="mm")
    y = 460
    for p in points:
        d.ellipse((32, y + 8, 52, y + 28), fill=tag_ink)
        for j, ln in enumerate(A.wrap(d, p, A.font(30, "Medium"), cw - 100)):
            d.text((70, y + j * 40), ln, font=A.font(30, "Medium"), fill=A.INK)
        y += 40 * len(A.wrap(d, p, A.font(30, "Medium"), cw - 100)) + 28
    A.shadow_paste(img, card, x, 360, blur=18, offset=10, alpha=55)


def render(out):
    img = T.background()
    d = ImageDraw.Draw(img)
    cx = W / 2
    f = A.font(80, "Heavy")
    d.text((cx, 100), "Don't pay the", font=f, fill=A.INK, anchor="mm")
    l2 = "wrong paper."
    w2 = d.textlength(l2, font=f)
    d.rounded_rectangle((cx - w2 / 2 - 24, 146, cx + w2 / 2 + 24, 234), radius=34, fill=A.LIME)
    d.text((cx, 190), l2, font=f, fill=A.INK, anchor="mm")
    d.text((cx, 278), "An EOB and a bill look alike. Only one asks for money.",
           font=A.font(32, "Semibold"), fill=A.SUB, anchor="mm")

    column(img, 60, "EOB", "FROM INSURANCE", BLUE_SOFT, BLUE, "Explanation of Benefits",
           ["Shows what insurance paid", "Says \"This is not a bill\"", "Keep it to compare"],
           "NOT A BILL", BLUE)
    column(img, 570, "The bill", "FROM THE HOSPITAL", A.LIME_SOFT, A.LIME_DEEP, "or doctor's office",
           ["Asks you to pay", "Check it against your EOB", "Ask for the itemized one"],
           "AMOUNT DUE", A.LIME_DEEP)

    d = ImageDraw.Draw(img)
    icon = Image.open(os.path.join(A.S, "devpost", "icon-1024.png")).convert("RGBA").resize((96, 96), Image.LANCZOS)
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 95, 95), radius=22, fill=255)
    fy = H - 140
    img.paste(icon, (70, fy), m)
    d.text((186, fy + 6), "Lime Shield tells them apart for you", font=A.font(34, "Bold"), fill=A.INK)
    d.text((186, fy + 52), "Free to try on the App Store · nothing leaves your phone",
           font=A.font(27, "Medium"), fill=A.SUB)
    os.makedirs(out, exist_ok=True)
    img.convert("RGB").save(os.path.join(out, "eob-vs-bill.png"))


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "infographic")
