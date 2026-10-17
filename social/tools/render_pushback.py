#!/usr/bin/env python3
"""One-page post, 1080x1350, bright style: "What to say when billing pushes back".
The lines are the app's own, from LimeShield/Pushback.swift.

    python3 render_pushback.py ../posts/infographic
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_appstore as A  # noqa: E402
import render_tips as T  # noqa: E402

W, H = 1080, 1350
GREY = (233, 236, 239)

EXCHANGES = [
    ("That's our standard rate.",
     "I understand. What's your self-pay or prompt-payment rate, and what discount can you apply?"),
    ("The service was performed twice.",
     "Then please point to each one separately in my medical record."),
]


def bubble(d_img, text, left, y, label):
    f, lf = A.font(40, "Semibold"), A.font(24, "Heavy")
    maxw = 780
    tmp = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    lines = A.wrap(tmp, text, f, maxw - 64)
    bw = int(max(tmp.textlength(ln, font=f) for ln in lines)) + 64
    bw = max(bw, int(tmp.textlength(label, font=lf)) + 64)
    bh = 70 + 54 * len(lines) + 24
    fill = WHITE if left else A.LIME
    layer = A.card(bw, bh, radius=36, fill=fill)
    d = ImageDraw.Draw(layer)
    d.text((32, 24), label, font=lf, fill=(130, 136, 140) if left else A.INK)
    yy = 62
    for ln in lines:
        d.text((32, yy), ln, font=f, fill=A.INK)
        yy += 54
    x = 70 if left else W - 70 - bw
    A.shadow_paste(d_img, layer, x, y, blur=16, offset=8, alpha=50)
    return y + bh


WHITE = (255, 255, 255)


def render(out):
    img = T.background()
    d = ImageDraw.Draw(img)
    cx = W / 2
    f = A.font(76, "Heavy")
    d.text((cx, 100), "What to say when", font=f, fill=A.INK, anchor="mm")
    l2 = "billing pushes back"
    w2 = d.textlength(l2, font=f)
    d.rounded_rectangle((cx - w2 / 2 - 24, 148, cx + w2 / 2 + 24, 232), radius=32, fill=A.LIME)
    d.text((cx, 190), l2, font=f, fill=A.INK, anchor="mm")
    d.text((cx, 272), "Polite. Clear. Asking is always allowed.", font=A.font(34, "Semibold"),
           fill=A.SUB, anchor="mm")

    y = 330
    for they, you in EXCHANGES:
        y = bubble(img, they, True, y, "BILLING SAYS") + 14
        y = bubble(img, you, False, y, "YOU SAY") + 50

    d = ImageDraw.Draw(img)
    icon = Image.open(os.path.join(A.S, "devpost", "icon-1024.png")).convert("RGBA").resize((96, 96), Image.LANCZOS)
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 95, 95), radius=22, fill=255)
    fy = H - 140
    img.paste(icon, (70, fy), m)
    d.text((186, fy + 6), "Lime Shield gives you the words", font=A.font(34, "Bold"), fill=A.INK)
    d.text((186, fy + 52), "for every charge it flags · free to try on the App Store",
           font=A.font(27, "Medium"), fill=A.SUB)

    os.makedirs(out, exist_ok=True)
    img.convert("RGB").save(os.path.join(out, "what-to-say.png"))


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "infographic")
