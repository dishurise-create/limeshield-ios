#!/usr/bin/env python3
"""One-page post, 1080x1350, bright style: a copy-and-paste phone script for
asking for an itemized bill.

    python3 render_script.py ../posts/infographic
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_appstore as A  # noqa: E402
import render_tips as T  # noqa: E402

W, H = 1080, 1350
SCRIPT = ("Hi, I'm calling about account number ____. Before I pay, could you send "
          "me an itemized bill with the billing code for every charge? Email or mail "
          "is fine. Thanks!")
WHY = [
    "A summary hides duplicates and extra fees",
    "You can always ask, and it costs nothing",
    "Then check it line by line before you pay",
]


def render(out):
    img = T.background()
    d = ImageDraw.Draw(img)
    cx = W / 2
    d.text((cx, 96), "Got a medical bill?", font=A.font(46, "Bold"), fill=A.SUB, anchor="mm")
    f = A.font(84, "Heavy")
    d.text((cx, 190), "Say this first.", font=f, fill=A.INK, anchor="mm")
    l2 = "Copy it word for word"
    w2 = d.textlength(l2, font=A.font(50, "Heavy"))
    d.rounded_rectangle((cx - w2 / 2 - 24, 250, cx + w2 / 2 + 24, 322), radius=30, fill=A.LIME)
    d.text((cx, 286), l2, font=A.font(50, "Heavy"), fill=A.INK, anchor="mm")

    # the script, as a big quote card
    sf = A.font(46, "Semibold")
    tmp = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    lines = A.wrap(tmp, SCRIPT, sf, W - 260)
    ch = 130 + 62 * len(lines) + 40
    card = A.card(W - 120, ch, radius=44)
    cd = ImageDraw.Draw(card)
    cd.text((50, 20), "“", font=A.font(130, "Heavy"), fill=A.LIME)
    y = 120
    for ln in lines:
        cd.text((60, y), ln, font=sf, fill=A.INK)
        y += 62
    A.shadow_paste(img, card, 60, 380, blur=18, offset=10, alpha=55)

    # why it works
    y = 380 + ch + 50
    d = ImageDraw.Draw(img)
    for item in WHY:
        d.ellipse((90, y + 6, 126, y + 42), fill=A.LIME)
        d.line((99, y + 25, 106, y + 33, 118, y + 16), fill=(255, 255, 255), width=6, joint="curve")
        d.text((150, y + 24), item, font=A.font(36, "Semibold"), fill=A.INK, anchor="lm")
        y += 70

    icon = Image.open(os.path.join(A.S, "devpost", "icon-1024.png")).convert("RGBA").resize((96, 96), Image.LANCZOS)
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 95, 95), radius=22, fill=255)
    fy = H - 140
    img.paste(icon, (70, fy), m)
    d.text((186, fy + 6), "Lime Shield checks it from a photo", font=A.font(34, "Bold"), fill=A.INK)
    d.text((186, fy + 52), "Free to try on the App Store · nothing leaves your phone",
           font=A.font(27, "Medium"), fill=A.SUB)

    os.makedirs(out, exist_ok=True)
    img.convert("RGB").save(os.path.join(out, "say-this-first.png"))


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "infographic")
