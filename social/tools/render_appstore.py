#!/usr/bin/env python3
"""App Store screenshots with marketing headlines, 1320x2868 (6.9" display).

    python3 render_appstore.py OUTPUT_DIR
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render_slides import BG, GREY, LIME, PILL_BG, WHITE, font  # noqa: E402

W, H = 1320, 2868
HERE = os.path.dirname(os.path.abspath(__file__))
S = os.path.join(HERE, "..")

SHOTS = [
    ("Check your medical bill", "before you pay.", "Snap a photo. See what's worth questioning in seconds.",
     os.path.join(S, "devpost", "01-results.png")),
    ("Spot charges worth", "questioning.", "Duplicates, totals that don't add up, vague fees.",
     os.path.join(S, "devpost", "01-results.png"), "crop_findings"),
    ("Know exactly", "what to say.", "The question to ask billing, and what to say if they push back.",
     os.path.join(S, "devpost", "02-finding.png")),
    ("Your bill never", "leaves your phone.", "No account. No upload. Works in airplane mode.",
     os.path.join(S, "screens", "home.png")),
    ("Try Pro free", "for a week.", "Then just $2.99/month. 2 free scans included.",
     os.path.join(S, "screens", "paywall-trial.png")),
]


def background():
    img = Image.new("RGB", (W, H), BG)
    glow = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(glow)
    d.ellipse((W * 0.35, -H * 0.2, W * 1.5, H * 0.35), fill=(36, 56, 14))
    d.ellipse((-W * 0.6, H * 0.65, W * 0.6, H * 1.3), fill=(22, 34, 10))
    return Image.blend(img, glow.filter(ImageFilter.GaussianBlur(220)), 0.95)


def centered(d, text, f, y, fill):
    d.text(((W - d.textlength(text, font=f)) / 2, y), text, font=f, fill=fill)


def wrap(d, text, f, width):
    out, line = [], ""
    for w in text.split():
        t = (line + " " + w).strip()
        if d.textlength(t, font=f) <= width or not line:
            line = t
        else:
            out.append(line); line = w
    return out + [line]


def phone(img, shot, top, h):
    w = int(shot.width * h / shot.height)
    shot = shot.resize((w, h), Image.LANCZOS)
    x = (W - w) // 2
    bez = 22
    frame = Image.new("RGB", (w + 2 * bez, h + 2 * bez), (58, 62, 68))
    fm = Image.new("L", frame.size, 0)
    ImageDraw.Draw(fm).rounded_rectangle((0, 0, *frame.size), radius=110, fill=255)
    # soft shadow
    sh = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sh).rounded_rectangle((x - bez, top - bez + 30, x + w + bez, top + h + bez + 30),
                                         radius=110, fill=150)
    img.paste((0, 0, 0), (0, 0), sh.filter(ImageFilter.GaussianBlur(40)))
    img.paste(frame, (x - bez, top - bez), fm)
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w, h), radius=92, fill=255)
    img.paste(shot, (x, top), m)


def render(i, spec, out):
    l1, l2, sub, path = spec[:4]
    mode = spec[4] if len(spec) > 4 else None
    img = background()
    d = ImageDraw.Draw(img)
    centered(d, l1, font(100, "Heavy"), 200, WHITE)
    centered(d, l2, font(100, "Heavy"), 320, LIME)
    y = 490
    for ln in wrap(d, sub, font(52), W - 220):
        centered(d, ln, font(52), y, GREY); y += 70
    shot = Image.open(path).convert("RGB")
    if mode == "crop_findings":
        # Zoom into the findings section and show it as a large card rather
        # than a phone, so each problem reads at a glance.
        sw, sh_ = shot.size
        card = shot.crop((int(sw * 0.03), int(sh_ * 0.565), int(sw * 0.97), int(sh_ * 0.875)))
        cw = W - 120
        ch = int(card.height * cw / card.width)
        card = card.resize((cw, ch), Image.LANCZOS)
        top = 820
        sh = Image.new("L", (W, H), 0)
        ImageDraw.Draw(sh).rounded_rectangle((60, top + 30, 60 + cw, top + ch + 30), radius=70, fill=150)
        img.paste((0, 0, 0), (0, 0), sh.filter(ImageFilter.GaussianBlur(40)))
        m = Image.new("L", (cw, ch), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, cw, ch), radius=70, fill=255)
        img.paste(card, (60, top), m)
        # Fill the space below with what the app checks, large enough to read
        # in the store's small preview.
        y = top + ch + 140
        d.text((110, y), "WHAT IT CHECKS", font=font(46, "Bold"), fill=LIME)
        y += 100
        for item in ["Same charge billed twice", "Lines that don't add up",
                     "Vague \"misc supplies\" fees", "Tests billed separately",
                     "Prices far above typical"]:
            d.rounded_rectangle((60, y, W - 60, y + 150), radius=48, fill=(28, 31, 36),
                                outline=(48, 54, 60), width=3)
            d.ellipse((120, y + 60, 150, y + 90), fill=(245, 158, 11))
            d.text((190, y + 44), item, font=font(58, "Semibold"), fill=WHITE)
            y += 180
        img.save(os.path.join(out, f"{i:02d}.png"))
        return
    top = 760
    phone(img, shot, top, H - top - 40 + 600)  # runs off the bottom edge, like store screenshots
    img = img.crop((0, 0, W, H))
    img.save(os.path.join(out, f"{i:02d}.png"))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "appstore"
    os.makedirs(out, exist_ok=True)
    for i, spec in enumerate(SHOTS, 1):
        render(i, spec, out)
    print("\n".join(sorted(os.listdir(out))))
