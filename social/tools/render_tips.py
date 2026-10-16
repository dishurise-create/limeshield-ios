#!/usr/bin/env python3
"""One-page infographic, 1080x1350 (Instagram/Facebook portrait), bright style:
"5 things to check on your medical bill".

    python3 render_tips.py ../posts/infographic
"""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_appstore as A  # noqa: E402

W, H = 1080, 1350

TIPS = [
    ("Ask for the itemized bill", "A summary hides the details. Ask to see every line."),
    ("Look for the same charge twice", "Same date, code and price? Ask if both happened."),
    ("Add up the lines", "Do the charges add up to the total? Sometimes they don't."),
    ("Question vague fees", "\"Misc supplies\" or \"room charge\"? Ask what it was for."),
    ("Check tests billed separately", "Blood tests are often billed as one panel, not one by one."),
]


def background():
    grad = A.gradient().crop((0, 0, A.PW // 2, 1)).resize((W, 1)).resize((W, H)).convert("RGBA")
    d = ImageDraw.Draw(grad)
    rnd = random.Random(11)
    cols = [A.LIME, A.ORANGE, A.BLUE, (255, 204, 0), (255, 105, 140)]
    for _ in range(26):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H)
        if 50 < x < W - 50 and 40 < y < H - 20:
            continue  # only along the edges, never over text
        c, s = rnd.choice(cols), rnd.uniform(6, 13)
        if rnd.random() < 0.5:
            d.ellipse((x - s, y - s, x + s, y + s), fill=c)
        else:
            A.sparkle(d, x, y, s * 2, c)
    return grad


def render(out):
    img = background()
    d = ImageDraw.Draw(img)
    cx = W / 2
    f = A.font(80, "Heavy")
    d.text((cx, 110), "5 things to check", font=f, fill=A.INK, anchor="mm")
    l2 = "on your medical bill"
    w2 = d.textlength(l2, font=f)
    d.rounded_rectangle((cx - w2 / 2 - 24, 160, cx + w2 / 2 + 24, 248), radius=34, fill=A.LIME)
    d.text((cx, 204), l2, font=f, fill=A.INK, anchor="mm")
    d.text((cx, 290), "before you pay it", font=A.font(38, "Semibold"), fill=A.SUB, anchor="mm")

    y = 340
    tf, sf = A.font(40, "Bold"), A.font(29, "Medium")
    for i, (t, s) in enumerate(TIPS, 1):
        lines = A.wrap(d, s, sf, W - 300)
        h = 96 + 38 * len(lines)
        card = A.card(W - 120, h, radius=40)
        cd = ImageDraw.Draw(card)
        cd.ellipse((30, 30, 106, 106), fill=A.LIME)
        cd.text((68, 68), str(i), font=A.font(46, "Heavy"), fill=A.INK, anchor="mm")
        cd.text((134, 34), t, font=tf, fill=A.INK)
        yy = 88
        for ln in lines:
            cd.text((134, yy), ln, font=sf, fill=A.SUB)
            yy += 38
        A.shadow_paste(img, card, 60, y, blur=18, offset=10, alpha=55)
        y += h + 22

    # footer
    d = ImageDraw.Draw(img)
    icon = Image.open(os.path.join(A.S, "devpost", "icon-1024.png")).convert("RGBA").resize((96, 96), Image.LANCZOS)
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 95, 95), radius=22, fill=255)
    fy = H - 140
    img.paste(icon, (70, fy), m)
    d.text((186, fy + 6), "Lime Shield checks these from a photo", font=A.font(34, "Bold"), fill=A.INK)
    d.text((186, fy + 52), "Free to try on the App Store · nothing leaves your phone",
           font=A.font(27, "Medium"), fill=A.SUB)

    os.makedirs(out, exist_ok=True)
    img.convert("RGB").save(os.path.join(out, "5-things-to-check.png"))


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "infographic")
