#!/usr/bin/env python3
"""One-page post, 1080x1350: teaser for the 1.0.1 update ("Meet Shield Buddy").

    python3 render_teaser.py ../posts/infographic
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_appstore as A  # noqa: E402
import render_tips as T  # noqa: E402

W, H = 1080, 1350
WHITE = (255, 255, 255)


def buddy(img, cx, cy, s):
    w, h = 150 * s, 175 * s
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((cx - w * 1.2, cy - h * 1.1, cx + w * 1.2, cy + h * 1.2), fill=(170, 240, 90, 90))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(60 * s)))
    d = ImageDraw.Draw(img)
    d.polygon([(cx - w, cy - h * .8), (cx, cy - h), (cx + w, cy - h * .8), (cx + w, cy + h * .05),
               (cx, cy + h), (cx - w, cy + h * .05)], fill=A.LIME)
    d.polygon([(cx - w * .82, cy - h * .68), (cx, cy - h * .84), (cx + w * .82, cy - h * .68),
               (cx + w * .82, cy), (cx, cy + h * .8), (cx - w * .82, cy)], fill=(150, 225, 70))
    ey = cy - h * .25
    for i, ex in enumerate((cx - w * .35, cx + w * .35)):
        d.ellipse((ex - 24 * s, ey - 30 * s, ex + 24 * s, ey + 30 * s), fill=WHITE)
        d.ellipse((ex - 6 * s, ey - 14 * s, ex + 18 * s, ey + 12 * s), fill=A.INK)
    d.arc((cx - 46 * s, cy - h * .05, cx + 46 * s, cy + h * .38), 20, 160, fill=A.INK, width=int(10 * s))


def render(out):
    img = T.background()
    d = ImageDraw.Draw(img)
    cx = W / 2
    d.text((cx, 110), "Coming October 30", font=A.font(40, "Bold"), fill=A.SUB, anchor="mm")
    f = A.font(96, "Heavy")
    d.text((cx, 215), "Meet my", font=f, fill=A.INK, anchor="mm")
    l2 = "Shield Buddy."
    w2 = d.textlength(l2, font=f)
    d.rounded_rectangle((cx - w2 / 2 - 26, 270, cx + w2 / 2 + 26, 376), radius=40, fill=A.LIME)
    d.text((cx, 323), l2, font=f, fill=A.INK, anchor="mm")

    buddy(img, cx, 660, 1.35)

    bubble = A.card(W - 200, 150, radius=44)
    bd = ImageDraw.Draw(bubble)
    bd.text(((W - 200) / 2, 75), "“I'll check your bill for you.”", font=A.font(46, "Heavy"),
            fill=A.INK, anchor="mm")
    A.shadow_paste(img, bubble, 100, 930, blur=16, offset=8, alpha=55)

    d = ImageDraw.Draw(img)
    for i, t in enumerate(["X-ray your bill", "Plain-word help", "Free to try"]):
        x = 90 + i * 310
        d.rounded_rectangle((x, 1130, x + 280, 1200), radius=35, fill=WHITE)
        d.text((x + 140, 1165), t, font=A.font(30, "Bold"), fill=A.INK, anchor="mm")
    d.text((cx, 1265), "Lime Shield · the medical bill checker built by an 11th grader",
           font=A.font(27, "Medium"), fill=A.SUB, anchor="mm")
    os.makedirs(out, exist_ok=True)
    img.convert("RGB").save(os.path.join(out, "buddy-teaser.png"))


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "infographic")
