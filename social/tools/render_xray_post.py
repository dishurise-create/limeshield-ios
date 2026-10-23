#!/usr/bin/env python3
"""One-page post, 1080x1350: the Bill X-ray screen in a phone, bright style.

    python3 render_xray_post.py ../posts/infographic
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_appstore as A  # noqa: E402
import render_tips as T  # noqa: E402

W, H = 1080, 1350


def render(out):
    img = T.background()
    d = ImageDraw.Draw(img)
    cx = W / 2
    f = A.font(84, "Heavy")
    d.text((cx, 100), "I gave my app", font=f, fill=A.INK, anchor="mm")
    l2 = "X-ray vision."
    w2 = d.textlength(l2, font=f)
    d.rounded_rectangle((cx - w2 / 2 - 24, 148, cx + w2 / 2 + 24, 240), radius=34, fill=A.LIME)
    d.text((cx, 194), l2, font=f, fill=A.INK, anchor="mm")
    d.text((cx, 285), "Snap a medical bill. Watch the problems light up.",
           font=A.font(34, "Semibold"), fill=A.SUB, anchor="mm")
    A.place(img, A.phone_layer(os.path.join(A.LIGHT, "reveal.png"), 880), cx, 350, 0)
    for t, a, c, right, y, ang in [("Charged twice", "$150", A.ORANGE, False, 1150, 5),
                                   ("Doesn't add up", None, A.RED, True, 1030, -4)]:
        st = A.sticker(t, a, dot=c, size=26).rotate(ang, resample=Image.BICUBIC, expand=True)
        x = W - st.width - 30 if right else 30
        A.shadow_paste(img, st, x, y, blur=14, offset=8, alpha=60)
    os.makedirs(out, exist_ok=True)
    img.convert("RGB").save(os.path.join(out, "xray-post.png"))


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "infographic")
