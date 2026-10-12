#!/usr/bin/env python3
"""Lime Shield "how it works" infographic, 1080x1350, in the house style.

    python3 render_infographic.py OUTPUT.png
"""
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render_slides import (BG, GREY, LIME, MARGIN, PILL_BG, W, WHITE,  # noqa: E402
                           background, font)

CARD = (28, 31, 36)
CARD_EDGE = (48, 54, 60)
ORANGE = (245, 158, 11)

STEPS = [
    ("Snap a photo", "of your itemized medical bill"),
    ("See what to question", "duplicates, bad math, vague fees"),
    ("Get the letter", "written for you, ready to send"),
]
CHECKS = [
    "Same charge billed twice",
    "Lines that don't add up",
    "Vague \"misc supplies\" fees",
    "Tests billed separately",
]


def centered(d, text, f, y, fill, x0=0, x1=W):
    w = d.textlength(text, font=f)
    d.text((x0 + (x1 - x0 - w) / 2, y), text, font=f, fill=fill)


def main(out):
    img = background()
    d = ImageDraw.Draw(img)

    # Label
    d.ellipse((MARGIN, 78, MARGIN + 14, 92), fill=LIME)
    d.text((MARGIN + 26, 66), "LIME SHIELD", font=font(30, "Bold"), fill=LIME)

    # Title
    y = 135
    d.text((MARGIN, y), "Check your medical bill", font=font(76, "Heavy"), fill=WHITE)
    y += 86
    d.text((MARGIN, y), "in 3 steps.", font=font(76, "Heavy"), fill=LIME)
    y += 120

    # Steps
    card_h = 118
    for i, (title, sub) in enumerate(STEPS, 1):
        top = y + (i - 1) * (card_h + 18)
        d.rounded_rectangle((MARGIN, top, W - MARGIN, top + card_h), radius=28,
                            fill=CARD, outline=CARD_EDGE, width=2)
        cx, cy, r = MARGIN + 66, top + card_h // 2, 36
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=LIME)
        centered(d, str(i), font(44, "Heavy"), cy - 28, BG, cx - r, cx + r)
        d.text((MARGIN + 130, top + 22), title, font=font(44, "Bold"), fill=WHITE)
        d.text((MARGIN + 130, top + 72), sub, font=font(30), fill=GREY)
    y += 3 * card_h + 2 * 18 + 50

    # What it checks
    d.text((MARGIN, y), "WHAT IT CHECKS", font=font(28, "Bold"), fill=LIME)
    y += 50
    col_w = (W - 2 * MARGIN - 20) // 2
    chip_h = 92
    for k, text in enumerate(CHECKS):
        col, row = k % 2, k // 2
        x = MARGIN + col * (col_w + 20)
        top = y + row * (chip_h + 16)
        d.rounded_rectangle((x, top, x + col_w, top + chip_h), radius=22,
                            fill=CARD, outline=CARD_EDGE, width=2)
        d.ellipse((x + 24, top + 38, x + 40, top + 54), fill=ORANGE)
        f = font(29, "Semibold")
        words, lines, line = text.split(), [], ""
        for w_ in words:
            t = (line + " " + w_).strip()
            if d.textlength(t, font=f) <= col_w - 80 or not line:
                line = t
            else:
                lines.append(line)
                line = w_
        lines.append(line)
        ty = top + (chip_h - 36 * len(lines)) // 2
        for ln in lines:
            d.text((x + 56, ty), ln, font=f, fill=WHITE)
            ty += 36
    y += 2 * chip_h + 16 + 44

    # Privacy band
    band_h = 84
    d.rounded_rectangle((MARGIN, y, W - MARGIN, y + band_h), radius=band_h // 2,
                        fill=PILL_BG, outline=(72, 110, 20), width=2)
    # lock icon
    lx, ly = MARGIN + 44, y + band_h // 2
    d.rounded_rectangle((lx - 14, ly - 4, lx + 14, ly + 20), radius=5, fill=LIME)
    d.arc((lx - 10, ly - 22, lx + 10, ly + 2), start=180, end=360, fill=LIME, width=5)
    d.text((MARGIN + 80, y + 22), "Your bill never leaves your phone",
           font=font(34, "Semibold"), fill=LIME)
    y += band_h + 40

    # Footer: price and maker
    d.text((MARGIN, y), "1-week free trial, then $2.99/mo", font=font(40, "Bold"), fill=WHITE)
    y += 54
    d.text((MARGIN, y), "Built by an 11th grader  ·  Free on the App Store",
           font=font(30), fill=GREY)

    img.save(out)
    print(out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "infographic.png")
