#!/usr/bin/env python3
"""Shield Buddy TikTok skit #1: "MISC SUPPLIES $340". 1080x1920, 30 fps, no
audio (add a trending sound in TikTok/CapCut). Writes PNG frames, then
frames_to_video.swift turns them into an MP4.

    python3 render_buddy_skit.py OUT_DIR
"""
import math
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_appstore as A  # noqa: E402

W, H, FPS = 1080, 1920, 30
INK, WHITE, ORANGE = A.INK, (255, 255, 255), A.ORANGE
F = A.font
MONO = A.MONO


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def seg(t, a, b):
    """0..1 progress of t through [a, b]."""
    return max(0.0, min(1.0, (t - a) / (b - a)))


# ---------- static layers ----------

def make_bg():
    g = Image.new("RGB", (W, H))
    px = g.load()
    c1, c2, c3 = (222, 248, 200), (255, 244, 186), (214, 236, 255)
    for y in range(H):
        for x in range(0, W, 4):
            t = (x / W * 0.4 + y / H * 0.6)
            a, b, k = (c1, c2, t / .5) if t < .5 else (c2, c3, (t - .5) / .5)
            c = tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))
            for dx in range(4):
                px[x + dx, y] = c
    return g.convert("RGBA")


ROWS = [("ER VISIT LEVEL 3", "$390"), ("ECG 12 LEADS", "$150"), ("BLOOD TEST", "$40"),
        ("MISC SUPPLIES", "$340"), ("TOTAL", "$920")]
MISC = 3


def make_bill(highlight=0.0, revealed=5):
    w, h = 840, 640
    card = Image.new("RGBA", (w + 80, h + 80), (0, 0, 0, 0))
    sh = Image.new("RGBA", card.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((40, 54, 40 + w, 54 + h), radius=30, fill=(20, 60, 20, 60))
    card.alpha_composite(sh.filter(ImageFilter.GaussianBlur(18)))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle((40, 40, 40 + w, 40 + h), radius=30, fill=(253, 252, 248))
    d.text((84, 84), "ST. SOMEWHERE HOSPITAL", font=F(30, "Heavy"), fill=INK)
    d.text((84, 128), "Patient statement", font=F(26, "Medium"), fill=(120, 130, 120))
    for i, (a, b) in enumerate(ROWS[:revealed]):
        y = 200 + i * 86
        if i == MISC and highlight > 0:
            glow = Image.new("RGBA", card.size, (0, 0, 0, 0))
            ImageDraw.Draw(glow).rounded_rectangle((64, y - 22, 40 + w - 24, y + 52), radius=18,
                                                   outline=ORANGE + (int(255 * highlight),), width=20)
            card.alpha_composite(glow.filter(ImageFilter.GaussianBlur(12)))
            d = ImageDraw.Draw(card)
            d.rounded_rectangle((64, y - 22, 40 + w - 24, y + 52), radius=18,
                                fill=(255, 236, 214, int(255 * highlight)), outline=ORANGE, width=5)
        if i == len(ROWS) - 1:
            d.line((84, y - 30, 40 + w - 44, y - 30), fill=(210, 215, 210), width=3)
        f = F(34, "Bold" if i == len(ROWS) - 1 else "Medium", MONO)
        d.text((84, y), a, font=f, fill=(60, 64, 60))
        d.text((40 + w - 44, y), b, font=f, fill=(60, 64, 60), anchor="ra")
    return card


def buddy(size, gaze=(0, 0), lid=0.0, mouth="smile", glow=True):
    s = size / 100
    pad = int(60 * s)
    im = Image.new("RGBA", (int(220 * s) + 2 * pad, int(250 * s) + 2 * pad), (0, 0, 0, 0))
    cx, cy = im.width / 2, im.height / 2
    w, h = 110 * s, 125 * s
    if glow:
        g = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(g).ellipse((cx - w * 1.15, cy - h * 1.05, cx + w * 1.15, cy + h * 1.15), fill=(150, 235, 70, 120))
        im.alpha_composite(g.filter(ImageFilter.GaussianBlur(28 * s)))
    d = ImageDraw.Draw(im)
    outer = [(cx - w, cy - h * .78), (cx, cy - h), (cx + w, cy - h * .78), (cx + w, cy + h * .05),
             (cx, cy + h), (cx - w, cy + h * .05)]
    inner = [(cx - w * .82, cy - h * .66), (cx, cy - h * .83), (cx + w * .82, cy - h * .66),
             (cx + w * .82, cy), (cx, cy + h * .8), (cx - w * .82, cy)]
    d.polygon(outer, fill=(126, 211, 33))
    d.polygon(inner, fill=(156, 228, 78))
    ey = cy - h * .22
    ew, eh = 21 * s, 27 * s
    for ex in (cx - w * .36, cx + w * .36):
        open_h = max(eh * (1 - lid * 0.92), 2.5 * s)
        d.ellipse((ex - ew, ey - open_h, ex + ew, ey + open_h), fill=WHITE)
        if lid < 0.85:
            px, py = ex + gaze[0] * ew * 0.45, ey + gaze[1] * open_h * 0.45
            pr = 10 * s
            d.ellipse((px - pr, py - pr, px + pr, py + pr), fill=INK)
            # upper lid line for side-eye
            if lid > 0.05:
                d.rectangle((ex - ew - 2, ey - eh - 2, ex + ew + 2, ey - open_h + 1), fill=(156, 228, 78))
    my = cy + h * .2
    if mouth == "smile":
        d.arc((cx - 34 * s, my - 26 * s, cx + 34 * s, my + 18 * s), 20, 160, fill=INK, width=int(8 * s))
    elif mouth == "o":
        d.ellipse((cx - 13 * s, my - 10 * s, cx + 13 * s, my + 22 * s), fill=INK)
    else:
        d.rounded_rectangle((cx - 22 * s, my, cx + 22 * s, my + 7 * s), radius=4 * s, fill=INK)
    return im


def caption(img, text, y, size=64, alpha=1.0):
    if alpha <= 0:
        return
    f = F(size, "Heavy")
    d0 = ImageDraw.Draw(img)
    tw = d0.textlength(text, font=f)
    box = Image.new("RGBA", (int(tw) + 70, int(size * 1.6)), (0, 0, 0, 0))
    bd = ImageDraw.Draw(box)
    bd.rounded_rectangle((0, 0, box.width - 1, box.height - 1), radius=int(size * 0.4),
                         fill=(255, 255, 255, int(245 * alpha)))
    bd.text((box.width / 2, box.height / 2), text, font=f, fill=INK + (int(255 * alpha),), anchor="mm")
    img.alpha_composite(box, (int((W - box.width) / 2), int(y)))


def paste_center(img, layer, cx, cy, scale=1.0):
    if scale != 1.0:
        layer = layer.resize((max(1, int(layer.width * scale)), max(1, int(layer.height * scale))), Image.LANCZOS)
    img.alpha_composite(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)))


# ---------- timeline ----------
DUR = 10.0
BG = make_bg()
BILLS = {n: make_bill(revealed=n) for n in range(0, 6)}
ICON = Image.open(os.path.join(A.S, "devpost", "icon-1024.png")).convert("RGBA").resize((200, 200), Image.LANCZOS)
im_mask = Image.new("L", (200, 200), 0)
ImageDraw.Draw(im_mask).rounded_rectangle((0, 0, 199, 199), radius=46, fill=255)
ICON.putalpha(im_mask)


def frame(t):
    img = BG.copy()
    # 0-2.6: bill rows appear one by one, buddy happily reading
    if t < 7.6:
        revealed = min(5, int(seg(t, 0.4, 2.6) * 5) + (1 if t >= 0.4 else 0))
        hl = 0.0
        if t >= 3.0:
            hl = 0.55 + 0.45 * math.sin((t - 3.0) * 7) if t < 5.6 else 1.0
        bill = make_bill(highlight=hl, revealed=revealed) if hl > 0 or revealed < 5 else BILLS[5]
        # camera push towards the misc line during the stare
        zoom = 1.0 + 0.18 * ease(seg(t, 3.2, 4.4)) - 0.18 * ease(seg(t, 6.2, 6.8))
        paste_center(img, bill, W / 2, 690 + 90 * (zoom - 1), zoom)

    # buddy
    if t < 7.6:
        if t < 3.0:
            b = buddy(150, gaze=(-0.4, -0.6), lid=0.0, mouth="smile")
            bob = math.sin(t * 5) * 8
            paste_center(img, b, 260, 1450 + bob)
        elif t < 4.6:
            k = ease(seg(t, 3.0, 4.2))
            size = lerp(150, 280, k)
            gaze = (lerp(-0.4, 0.0, ease(seg(t, 3.5, 4.4))), lerp(-0.6, 0.0, ease(seg(t, 3.5, 4.4))))
            b = buddy(size, gaze=gaze, lid=0.0, mouth="o")
            paste_center(img, b, lerp(260, W / 2, k), lerp(1450, 1580, k))
        elif t < 6.2:
            # side-eye at the camera
            lid = 0.45 * ease(seg(t, 4.6, 4.9))
            b = buddy(280, gaze=(0.55, 0.15), lid=lid, mouth="flat")
            paste_center(img, b, W / 2, 1580)
        else:
            k = ease(seg(t, 6.2, 6.7))
            b = buddy(lerp(280, 220, k), gaze=(-0.3, -0.4), lid=0.0, mouth="flat")
            paste_center(img, b, lerp(W / 2, 220, k), lerp(1580, 1520, k))

    # X-ray beam sweep 6.4-7.4 with sticker
    if 6.4 <= t < 7.6:
        p = ease(seg(t, 6.4, 7.2))
        top, bottom = 690 - 330, 690 + 330
        y = lerp(top, bottom, p)
        beam = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(beam).rectangle((80, y - 30, W - 80, y + 30), fill=(150, 235, 70, 170))
        img.alpha_composite(beam.filter(ImageFilter.GaussianBlur(18)))
        ImageDraw.Draw(img).line((80, y, W - 80, y), fill=(170, 245, 80), width=6)
        if t >= 6.9:
            st = A.sticker("Worth asking about", "$340", dot=ORANGE, size=46)
            a = ease(seg(t, 6.9, 7.2))
            st = st.rotate(-4, resample=Image.BICUBIC, expand=True)
            paste_center(img, st, W / 2 + 120, 1180, 0.6 + 0.4 * a)

    # captions
    if t < 3.0:
        caption(img, "me checking my hospital bill", 170, 60)
    elif t < 4.6:
        caption(img, "wait.", 170, 80, ease(seg(t, 3.2, 3.5)))
    elif t < 6.4:
        caption(img, "$340 of... what supplies?", 170, 62)
    elif t < 7.6:
        caption(img, "X-ray mode: on", 170, 70)

    # end card 7.6-10
    if t >= 7.6:
        a = ease(seg(t, 7.6, 8.0))
        paste_center(img, ICON, W / 2, 560)
        d = ImageDraw.Draw(img)
        f = F(84, "Heavy")
        d.text((W / 2, 760), "Ask for the", font=f, fill=INK, anchor="mm")
        l2 = "itemized bill."
        w2 = d.textlength(l2, font=f)
        d.rounded_rectangle((W / 2 - w2 / 2 - 26, 810, W / 2 + w2 / 2 + 26, 910), radius=38, fill=(126, 211, 33))
        d.text((W / 2, 860), l2, font=f, fill=INK, anchor="mm")
        d.text((W / 2, 990), "Lime Shield checks it from a photo.", font=F(46, "Semibold"), fill=A.SUB, anchor="mm")
        d.text((W / 2, 1060), "Free to try · built by an 11th grader", font=F(40, "Medium"), fill=A.SUB, anchor="mm")
        wink = 0.9 if 8.8 < t < 9.05 else 0.0
        b = buddy(260, gaze=(0, 0.2), lid=wink, mouth="smile")
        paste_center(img, b, W / 2, 1420 + math.sin(t * 5) * 10)
        if a < 1:
            fade = Image.new("RGBA", (W, H), (255, 255, 255, int(255 * (1 - a))))
            img.alpha_composite(fade)
    return img.convert("RGB")


def main(out):
    frames = os.path.join(out, "frames")
    shutil.rmtree(frames, ignore_errors=True)
    os.makedirs(frames)
    n = int(DUR * FPS)
    for i in range(n):
        frame(i / FPS).save(os.path.join(frames, f"{i:04d}.png"), compress_level=1)
    tool = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frames_to_video.swift")
    subprocess.run(["swift", tool, frames, os.path.join(out, "buddy-misc-supplies.mp4"), str(FPS)], check=True)
    for t in (1.5, 4.0, 5.5, 7.0, 9.0):
        frame(t).resize((360, 640)).save(os.path.join(out, f"preview-{t:.1f}.png"))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "skit")
