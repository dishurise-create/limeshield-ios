#!/usr/bin/env python3
"""Product Hunt gallery images (1270x760) and thumbnail (240x240), house style.

    python3 render_producthunt.py OUTPUT_DIR
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render_slides import BG, GREY, LIME, PILL_BG, WHITE, font  # noqa: E402

W, H = 1270, 760
M = 70
CARD = (28, 31, 36)
EDGE = (48, 54, 60)
ORANGE = (245, 158, 11)
HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(HERE, "..", "devpost")


def bg():
    img = Image.new("RGB", (W, H), BG)
    glow = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(glow)
    d.ellipse((W * 0.5, -H * 0.5, W * 1.4, H * 0.5), fill=(34, 52, 14))
    d.ellipse((-W * 0.4, H * 0.6, W * 0.4, H * 1.5), fill=(22, 34, 10))
    return Image.blend(img, glow.filter(ImageFilter.GaussianBlur(140)), 0.9)


def label(d):
    d.ellipse((M, 62, M + 12, 74), fill=LIME)
    d.text((M + 22, 52), "LIME SHIELD", font=font(26, "Bold"), fill=LIME)


def wrap(d, text, f, width):
    out, line = [], ""
    for w in text.split():
        t = (line + " " + w).strip()
        if d.textlength(t, font=f) <= width or not line:
            line = t
        else:
            out.append(line)
            line = w
    return out + [line]


def text_block(d, x, y, lines, f, fill, gap):
    for ln in lines:
        d.text((x, y), ln, font=f, fill=fill)
        y += gap
    return y


def phone(img, path, x, y, h):
    shot = Image.open(path).convert("RGB")
    w = int(shot.width * h / shot.height)
    shot = shot.resize((w, h), Image.LANCZOS)
    # crop off the bottom tab bar fade for a cleaner frame
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w, h), radius=40, fill=255)
    frame = Image.new("RGB", (w + 16, h + 16), (60, 64, 70))
    fmask = Image.new("L", frame.size, 0)
    ImageDraw.Draw(fmask).rounded_rectangle((0, 0, *frame.size), radius=48, fill=255)
    img.paste(frame, (x - 8, y - 8), fmask)
    img.paste(shot, (x, y), mask)
    return w


def headline(d, x, y, parts, size, width):
    """parts: list of (text, colour) on one or more wrapped lines."""
    f = font(size, "Heavy")
    for text, colour in parts:
        for ln in wrap(d, text, f, width):
            d.text((x, y), ln, font=f, fill=colour)
            y += int(size * 1.1)
    return y


def img1(out):
    img = bg(); d = ImageDraw.Draw(img); label(d)
    y = headline(d, M, 140, [("Check your medical", WHITE), ("bill before you pay.", LIME)], 66, 700)
    y += 24
    y = text_block(d, M, y, wrap(d, "Snap a photo. See which charges are worth questioning. "
                                    "Get the letter to billing, written for you.", font(30), 640),
                   font(30), GREY, 42)
    y += 30
    d.rounded_rectangle((M, y, M + 520, y + 70), radius=35, fill=PILL_BG, outline=(72, 110, 20), width=2)
    d.text((M + 32, y + 16), "Free trial · then $2.99/mo", font=font(32, "Semibold"), fill=LIME)
    phone(img, os.path.join(SHOTS, "01-results.png"), 870, 60, 640)
    img.save(os.path.join(out, "1-hero.png"))


def img2(out):
    img = bg(); d = ImageDraw.Draw(img); label(d)
    headline(d, M, 110, [("How it works", WHITE)], 60, 1100)
    steps = [("1", "Snap a photo", "of your itemized medical bill"),
             ("2", "See what to question", "duplicates, bad math, vague fees"),
             ("3", "Get the letter", "written for you, ready to send")]
    cw = (W - 2 * M - 2 * 30) // 3
    for i, (n, t, s) in enumerate(steps):
        x = M + i * (cw + 30); top = 250
        d.rounded_rectangle((x, top, x + cw, top + 400), radius=32, fill=CARD, outline=EDGE, width=2)
        cx, cy, r = x + 70, top + 80, 42
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=LIME)
        nf = font(50, "Heavy"); nw = d.textlength(n, font=nf)
        d.text((cx - nw / 2, cy - 32), n, font=nf, fill=BG)
        yy = text_block(d, x + 34, top + 160, wrap(d, t, font(40, "Bold"), cw - 60), font(40, "Bold"), WHITE, 48)
        text_block(d, x + 34, yy + 14, wrap(d, s, font(28), cw - 60), font(28), GREY, 38)
    img.save(os.path.join(out, "2-how-it-works.png"))


def img3(out):
    img = bg(); d = ImageDraw.Draw(img); label(d)
    y = headline(d, M, 140, [("Tells you exactly", WHITE), ("what to ask.", LIME)], 62, 700)
    y += 30
    for b in ["The exact lines from your bill", "The question to ask billing, one tap to copy",
              "What to say if they push back"]:
        d.ellipse((M + 4, y + 14, M + 20, y + 30), fill=LIME)
        y = text_block(d, M + 44, y, wrap(d, b, font(32, "Medium"), 620), font(32, "Medium"), WHITE, 42) + 18
    phone(img, os.path.join(SHOTS, "02-finding.png"), 870, 60, 640)
    img.save(os.path.join(out, "3-what-to-ask.png"))


def img4(out):
    img = bg(); d = ImageDraw.Draw(img); label(d)
    headline(d, M, 110, [("Private and honest by design.", WHITE)], 56, 1130)
    cards = [("Never leaves your phone", "On-device text recognition. No server, no account, works in airplane mode."),
             ("Never accuses unfairly", "Only says \"error\" when the math is provably wrong. Everything else is a question."),
             ("Open source", "Built by an 11th grader. Read every line of the code on GitHub.")]
    cw = (W - 2 * M - 2 * 30) // 3
    for i, (t, s) in enumerate(cards):
        x = M + i * (cw + 30); top = 240
        d.rounded_rectangle((x, top, x + cw, top + 420), radius=32, fill=CARD, outline=EDGE, width=2)
        d.rounded_rectangle((x + 34, top + 40, x + 98, top + 104), radius=18, fill=PILL_BG, outline=(72, 110, 20), width=2)
        d.ellipse((x + 56, top + 62, x + 76, top + 82), fill=LIME)
        yy = text_block(d, x + 34, top + 136, wrap(d, t, font(36, "Bold"), cw - 60), font(36, "Bold"), WHITE, 44)
        text_block(d, x + 34, yy + 14, wrap(d, s, font(27), cw - 60), font(27), GREY, 37)
    img.save(os.path.join(out, "4-private-honest.png"))


def thumb(out):
    icon = Image.open(os.path.join(SHOTS, "icon-1024.png")).convert("RGB")
    icon.resize((240, 240), Image.LANCZOS).save(os.path.join(out, "thumbnail-240.png"))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "producthunt"
    os.makedirs(out, exist_ok=True)
    for f in (img1, img2, img3, img4, thumb):
        f(out)
    print("\n".join(sorted(os.listdir(out))))
