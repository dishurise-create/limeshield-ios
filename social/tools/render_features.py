#!/usr/bin/env python3
"""One-page "what Lime Shield can do" infographic with real phone screenshots.

    python3 render_features.py OUTPUT.png      (1080x1350)
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render_slides import BG, GREY, LIME, MARGIN, PILL_BG, W, WHITE, background, font  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SOCIAL = os.path.join(HERE, "..")


def phone(img, path, cx, top, h):
    shot = Image.open(path).convert("RGB")
    w = int(shot.width * h / shot.height)
    shot = shot.resize((w, h), Image.LANCZOS)
    x = cx - w // 2
    frame = Image.new("RGB", (w + 14, h + 14), (62, 66, 72))
    fm = Image.new("L", frame.size, 0)
    ImageDraw.Draw(fm).rounded_rectangle((0, 0, *frame.size), radius=40, fill=255)
    img.paste(frame, (x - 7, top - 7), fm)
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w, h), radius=34, fill=255)
    img.paste(shot, (x, top), m)
    return x, w


def centered(d, text, f, cx, y, fill):
    d.text((cx - d.textlength(text, font=f) / 2, y), text, font=f, fill=fill)


def main(out):
    img = background()
    d = ImageDraw.Draw(img)
    d.ellipse((MARGIN, 78, MARGIN + 14, 92), fill=LIME)
    d.text((MARGIN + 26, 66), "LIME SHIELD", font=font(30, "Bold"), fill=LIME)

    d.text((MARGIN, 130), "Check your medical", font=font(72, "Heavy"), fill=WHITE)
    d.text((MARGIN, 210), "bill before you pay.", font=font(72, "Heavy"), fill=LIME)

    shots = [
        (os.path.join(SOCIAL, "screens", "home.png"), "1  Snap a photo", "of your itemized bill"),
        (os.path.join(SOCIAL, "devpost", "01-results.png"), "2  See what's off", "duplicates, bad math, vague fees"),
        (os.path.join(SOCIAL, "devpost", "02-finding.png"), "3  Know what to say", "exact words + the letter"),
    ]
    col = (W - 2 * MARGIN) / 3
    top, h = 340, 600
    for i, (path, title, sub) in enumerate(shots):
        cx = int(MARGIN + col * i + col / 2)
        phone(img, path, cx, top, h)
        centered(d, title, font(32, "Bold"), cx, top + h + 26, WHITE)
        f = font(23)
        words, lines, line = sub.split(), [], ""
        for w_ in words:
            t = (line + " " + w_).strip()
            if d.textlength(t, font=f) <= col - 20 or not line:
                line = t
            else:
                lines.append(line); line = w_
        lines.append(line)
        y = top + h + 70
        for ln in lines:
            centered(d, ln, f, cx, y, GREY); y += 30

    band_y = 1100
    d.rounded_rectangle((MARGIN, band_y, W - MARGIN, band_y + 76), radius=38,
                        fill=PILL_BG, outline=(72, 110, 20), width=2)
    lx, ly = MARGIN + 42, band_y + 38
    d.rounded_rectangle((lx - 13, ly - 3, lx + 13, ly + 19), radius=5, fill=LIME)
    d.arc((lx - 9, ly - 20, lx + 9, ly + 2), start=180, end=360, fill=LIME, width=5)
    d.text((MARGIN + 76, band_y + 19), "Nothing uploaded. Your bill stays on your phone.",
           font=font(30, "Semibold"), fill=LIME)

    d.text((MARGIN, 1210), "1-week free trial, then $2.99/mo", font=font(38, "Bold"), fill=WHITE)
    d.text((MARGIN, 1262), "Built by an 11th grader  ·  Free on the App Store", font=font(28), fill=GREY)
    img.save(out)
    print(out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "features.png")
