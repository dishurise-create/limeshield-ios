#!/usr/bin/env python3
"""App Store In-App Event media, bright style, no words (Apple lays the event
name and description over the image, so the bottom stays calm):
  event-card-1920x1080.png   (event card, landscape)
  event-details-1080x1920.png (event details page, portrait)

    python3 render_event.py ../posts/appstore/event
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_appstore as A  # noqa: E402


def background(w, h, seed):
    row = A.gradient().crop((0, 0, A.PW, 1)).resize((w, 1))
    img = row.resize((w, h)).convert("RGBA")
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    base = h * 0.55
    for off, thick, col in [(0, h * 0.18, A.LIME_SOFT + (255,)), (h * 0.04, h * 0.09, A.LIME + (235,))]:
        top = [(x, base + off + h * 0.12 * math.sin(x / w * 2 * math.pi * 1.2 + 0.5)) for x in range(-20, w + 40, 10)]
        bot = [(x, y + thick) for x, y in reversed(top)]
        d.polygon(top + bot, fill=col)
    img.alpha_composite(layer)
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img)
    cols = [A.LIME, A.ORANGE, A.BLUE, (255, 204, 0), (255, 105, 140)]
    for _ in range(34):
        x, y = rnd.uniform(0, w), rnd.uniform(0, h * 0.7)
        c, s = rnd.choice(cols), rnd.uniform(8, 18) * w / 1920
        if rnd.random() < 0.5:
            d.ellipse((x - s, y - s, x + s, y + s), fill=c)
        else:
            A.sparkle(d, x, y, s * 2, c)
    return img


def soften_bottom(img, frac):
    """Gentle fade at the bottom so Apple's overlaid text stays readable."""
    w, h = img.size
    fade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = fade.load()
    start = int(h * (1 - frac))
    for y in range(start, h):
        a = int(150 * ((y - start) / (h - start)) ** 1.6)
        for x in range(w):
            px[x, y] = (20, 54, 26, a)
    img.alpha_composite(fade)


def card(out):
    w, h = 1920, 1080
    img = background(w, h, 5)
    L = A.LIGHT
    A.place(img, A.phone_layer(os.path.join(L, "walkthrough.png"), 860), 1180, 170, 8)
    A.place(img, A.phone_layer(os.path.join(L, "reveal.png"), 940), 1560, 90, -6)
    bp = A.bill_paper(-10)
    bp = bp.resize((int(bp.width * 0.95), int(bp.height * 0.95)))
    A.shadow_paste(img, bp, 360, 150)
    img.alpha_composite(A.magnifier(130), (620, 380))
    soften_bottom(img, 0.32)
    img.convert("RGB").save(os.path.join(out, "event-card-1920x1080.png"))


def details(out):
    w, h = 1080, 1920
    img = background(w, h, 9)
    L = A.LIGHT
    A.place(img, A.phone_layer(os.path.join(L, "reveal.png"), 1050), 600, 200, -5)
    bp = A.bill_paper(12)
    bp = bp.resize((int(bp.width * 0.72), int(bp.height * 0.72)))
    A.shadow_paste(img, bp, 40, 760)
    img.alpha_composite(A.magnifier(95), (210, 1000))
    soften_bottom(img, 0.30)
    img.convert("RGB").save(os.path.join(out, "event-details-1080x1920.png"))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "event"
    os.makedirs(out, exist_ok=True)
    card(out)
    details(out)
    print("\n".join(sorted(os.listdir(out))))
