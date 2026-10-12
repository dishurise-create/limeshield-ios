#!/usr/bin/env python3
"""App Store search-results card, 3840x2560, matching the bright screenshots.

Shown small in search, so the headline is huge and there are only three
stickers.

    python3 render_search_card.py ../posts/appstore
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_appstore as A  # noqa: E402
import render_header as Hd  # noqa: E402

CW, CH = 3840, 2560


def render(out):
    Hd.HW, Hd.HH = CW, CH
    img = Hd.background()
    d = ImageDraw.Draw(img)
    cx = CW // 2
    f = A.font(250, "Heavy")
    d.text((cx, 260), "Check your medical bill", font=f, fill=A.INK, anchor="mm")
    l2 = "before you pay."
    w2 = d.textlength(l2, font=f)
    d.rounded_rectangle((cx - w2 / 2 - 60, 420, cx + w2 / 2 + 60, 650), radius=90, fill=A.LIME)
    d.text((cx, 535), l2, font=f, fill=A.INK, anchor="mm")

    L = A.LIGHT
    A.place(img, A.phone_layer(os.path.join(L, "finding.png"), 1800), cx - 760, 960, 9)
    A.place(img, A.phone_layer(os.path.join(L, "home.png"), 1800), cx + 760, 960, -9)
    A.place(img, A.phone_layer(os.path.join(L, "results.png"), 1950), cx, 820, 0)

    for t, a, c, x, y, ang in [("Same charge twice", "$150", A.ORANGE, 90, 1150, 5),
                               ("Doesn't add up", "$150", A.RED, 200, 1500, -4)]:
        st = A.sticker(t, a, dot=c, size=80).rotate(ang, resample=Image.BICUBIC, expand=True)
        A.shadow_paste(img, st, x, y)
    for i, (ic, t) in enumerate([(A.ic_cloud_off, "No upload"), (A.ic_lock, "On-device")]):
        bg = A.badge(ic, t, 520).rotate((-1) ** i * 4, resample=Image.BICUBIC, expand=True)
        bg = bg.resize((int(bg.width * 1.5), int(bg.height * 1.5)), Image.LANCZOS)
        A.shadow_paste(img, bg, CW - bg.width - 120 - i * 80, 1150 + i * 330)
    s = A.sticker("1 week free", dot=A.LIME, size=86).rotate(-7, resample=Image.BICUBIC, expand=True)
    A.shadow_paste(img, s, cx + 180, 780)

    os.makedirs(out, exist_ok=True)
    img.convert("RGB").save(os.path.join(out, "search-3840x2560.png"))


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "appstore")
