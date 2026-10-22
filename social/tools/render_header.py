#!/usr/bin/env python3
"""App Store header banner, 3840x1646, matching the bright screenshots.

Apple may crop the sides on narrow screens and lay the app name over the
bottom, so the phones sit in the centre and the edges are decoration only.

    python3 render_header.py ../posts/appstore
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_appstore as A  # noqa: E402

HW, HH = 3840, 1646


def background():
    row = A.gradient().crop((0, 0, A.PW, 1)).resize((HW, 1))
    img = row.resize((HW, HH)).convert("RGBA")
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for base, thick, col in [(900, 300, A.LIME_SOFT + (255,)), (970, 150, A.LIME + (235,))]:
        top = [(x, base + 220 * math.sin(x / HW * 2 * math.pi * 1.5 + 0.4)) for x in range(-40, HW + 60, 20)]
        bot = [(x, y + thick) for x, y in reversed(top)]
        d.polygon(top + bot, fill=col)
    img.alpha_composite(layer)
    rnd = random.Random(3)
    d = ImageDraw.Draw(img)
    cols = [A.LIME, A.ORANGE, A.BLUE, (255, 204, 0), (255, 105, 140), A.LIME_DEEP]
    for _ in range(60):
        x, y = rnd.uniform(0, HW), rnd.uniform(40, HH - 40)
        if 1150 < x < 2690:
            continue  # keep the phones' area clean
        c, s = rnd.choice(cols), rnd.uniform(14, 28)
        if rnd.random() < 0.5:
            d.ellipse((x - s, y - s, x + s, y + s), fill=c)
        else:
            A.sparkle(d, x, y, s * 2, c)
    return img


def render(out):
    img = background()
    L = A.LIGHT
    cx = HW // 2
    # three fanned phones in the middle
    A.place(img, A.phone_layer(os.path.join(L, "walkthrough.png"), 1380), cx - 560, 260, 9)
    A.place(img, A.phone_layer(os.path.join(L, "home.png"), 1380), cx + 560, 260, -9)
    A.place(img, A.phone_layer(os.path.join(L, "reveal.png"), 1500), cx, 150, 0)

    # stickers either side of the phones
    for t, a, c, x, y, ang in [("Same charge twice", "$150", A.ORANGE, cx - 1500, 300, 5),
                               ("Doesn't add up", "$150", A.RED, cx - 1380, 560, -4),
                               ("Vague \"misc supplies\"", "$340", A.ORANGE, cx - 1480, 800, 3)]:
        st = A.sticker(t, a, dot=c, size=54).rotate(ang, resample=Image.BICUBIC, expand=True)
        A.shadow_paste(img, st, x, y)
    for i, (ic, t) in enumerate([(A.ic_person_off, "No account"), (A.ic_cloud_off, "No upload"),
                                 (A.ic_lock, "On-device")]):
        bg = A.badge(ic, t, 500).rotate((-1) ** i * 4, resample=Image.BICUBIC, expand=True)
        A.shadow_paste(img, bg, cx + 920 + (i % 2) * 90, 300 + i * 260)
    s = A.sticker("1 week free", dot=A.LIME, size=60).rotate(-7, resample=Image.BICUBIC, expand=True)
    A.shadow_paste(img, s, cx + 120, 120)

    # bill + magnifier far left, letter envelope far right (cropped first on small screens)
    bp = A.bill_paper(-14)
    A.shadow_paste(img, bp, -40, 980)
    img.alpha_composite(A.magnifier(120), (190, 1250))
    env = A.envelope(620, 400).rotate(12, resample=Image.BICUBIC, expand=True)
    A.shadow_paste(img, env, HW - 760, 1050)

    os.makedirs(out, exist_ok=True)
    img.convert("RGB").save(os.path.join(out, "header-3840x1646.png"))


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "appstore")
