#!/usr/bin/env python3
"""One-page post, 1080x1350, bright style: the builder story
("my app was wrong 4 out of 5 times").

    python3 render_story.py ../posts/infographic
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
    d.text((cx, 96), "I'm in 11th grade. My app's math check", font=A.font(44, "Bold"), fill=A.SUB, anchor="mm")
    f = A.font(92, "Heavy")
    d.text((cx, 200), "was wrong", font=f, fill=A.INK, anchor="mm")
    l2 = "4 out of 5 times."
    w2 = d.textlength(l2, font=f)
    d.rounded_rectangle((cx - w2 / 2 - 26, 252, cx + w2 / 2 + 26, 356), radius=38, fill=A.LIME)
    d.text((cx, 304), l2, font=f, fill=A.INK, anchor="mm")

    # five bill icons: four wrong, one right
    y0, size, gap = 430, 150, 30
    x0 = (W - (5 * size + 4 * gap)) / 2
    for i in range(5):
        x = x0 + i * (size + gap)
        card = A.card(size, int(size * 1.25), radius=24)
        cd = ImageDraw.Draw(card)
        for r in range(4):
            cd.rounded_rectangle((22, 30 + r * 30, size - 22, 44 + r * 30), radius=7, fill=(214, 220, 214))
        A.shadow_paste(img, card, x, y0, blur=14, offset=8, alpha=50)
        d = ImageDraw.Draw(img)
        bx, by, r = x + size - 18, y0 + 6, 34
        ok = i == 4
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=A.LIME if ok else A.RED)
        if ok:
            d.line((bx - 15, by, bx - 4, by + 12, bx + 16, by - 12), fill=WHITE, width=9, joint="curve")
        else:
            d.line((bx - 13, by - 13, bx + 13, by + 13), fill=WHITE, width=9)
            d.line((bx - 13, by + 13, bx + 13, by - 13), fill=WHITE, width=9)
    d.text((cx, y0 + 230), "Tested on real hospital bills, it said honest bills didn't add up.",
           font=A.font(30, "Medium"), fill=A.SUB, anchor="mm")

    # what I changed
    y = 760
    card = A.card(W - 120, 330, radius=40)
    cd = ImageDraw.Draw(card)
    cd.text((44, 40), "So I rebuilt it with one rule:", font=A.font(38, "Bold"), fill=A.INK)
    rule = "Only call it an error when the math proves it. Everything else is a question."
    yy = 104
    for ln in A.wrap(cd, rule, A.font(44, "Heavy"), W - 220):
        cd.text((44, yy), ln, font=A.font(44, "Heavy"), fill=A.LIME_DEEP)
        yy += 58
    yy += 22
    for ln in A.wrap(cd, "Better to stay quiet than accuse an honest hospital.", A.font(32, "Medium"), W - 220):
        cd.text((44, yy), ln, font=A.font(32, "Medium"), fill=A.SUB)
        yy += 42
    A.shadow_paste(img, card, 60, y, blur=18, offset=10, alpha=55)

    d = ImageDraw.Draw(img)
    icon = Image.open(os.path.join(A.S, "devpost", "icon-1024.png")).convert("RGBA").resize((96, 96), Image.LANCZOS)
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 95, 95), radius=22, fill=255)
    fy = H - 140
    img.paste(icon, (70, fy), m)
    d.text((186, fy + 6), "Lime Shield: check your medical bill", font=A.font(34, "Bold"), fill=A.INK)
    d.text((186, fy + 52), "Free to try on the App Store · nothing leaves your phone",
           font=A.font(27, "Medium"), fill=A.SUB)

    os.makedirs(out, exist_ok=True)
    img.convert("RGB").save(os.path.join(out, "builder-story.png"))


WHITE = (255, 255, 255)

if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "infographic")
