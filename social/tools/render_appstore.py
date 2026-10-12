#!/usr/bin/env python3
"""App Store screenshots, 1320x2868 (6.9" display), bright and connected.

One wide panorama (5 panels) is drawn first and then sliced, so the ribbon,
confetti and illustrations flow from one screenshot into the next, the way
DuckDuckGo's store page does. Uses the light-mode captures in
social/screens/light/.

    python3 render_appstore.py ../posts/appstore
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
N = 5
PW = W * N
HERE = os.path.dirname(os.path.abspath(__file__))
S = os.path.join(HERE, "..")
LIGHT = os.path.join(S, "screens", "light")
ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
MONO = "/System/Library/Fonts/SFNSMono.ttf"

INK = (20, 54, 26)          # headline
SUB = (62, 90, 64)          # body text
LIME = (126, 211, 33)       # bright lime, the app's colour turned up
LIME_DEEP = (86, 160, 12)
LIME_SOFT = (214, 245, 168)
ORANGE = (255, 149, 0)
RED = (255, 69, 58)
BLUE = (10, 132, 255)
WHITE = (255, 255, 255)

# Background colour stops across the whole panorama: mint, lemon, sky, peach, mint.
STOPS = [(0.0, (222, 248, 200)), (0.25, (255, 244, 186)), (0.5, (214, 236, 255)),
         (0.75, (255, 226, 206)), (1.0, (222, 248, 200))]


def font(size, weight="Regular", path=ROUNDED):
    f = ImageFont.truetype(path, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient():
    row = Image.new("RGB", (PW, 1))
    px = row.load()
    for x in range(PW):
        t = x / (PW - 1)
        for (t0, c0), (t1, c1) in zip(STOPS, STOPS[1:]):
            if t0 <= t <= t1:
                k = (t - t0) / (t1 - t0)
                k = k * k * (3 - 2 * k)
                px[x, 0] = lerp(c0, c1, k)
                break
    return row.resize((PW, H))


def ribbon(img):
    """A thick lime wave running through every panel, behind the phones."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    def wave(off, amp, base):
        return [(x, base + amp * math.sin(x / PW * 2 * math.pi * 2.5 + off)
                 + 90 * math.sin(x / 700.0)) for x in range(-50, PW + 60, 20)]
    for base, thick, col in [(2050, 300, LIME_SOFT + (255,)), (2120, 150, LIME + (235,))]:
        top = wave(0.6, 260, base)
        bot = [(x, y + thick) for x, y in reversed(top)]
        d.polygon(top + bot, fill=col)
    img.alpha_composite(layer)


def sparkle(d, cx, cy, r, fill):
    pts = []
    for i in range(8):
        a = i * math.pi / 4
        rr = r if i % 2 == 0 else r * 0.32
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill)


def confetti(img):
    rnd = random.Random(7)
    d = ImageDraw.Draw(img)
    cols = [LIME, ORANGE, BLUE, (255, 204, 0), (255, 105, 140), LIME_DEEP]
    for _ in range(90):
        x = rnd.uniform(0, PW)
        y = rnd.uniform(820, H - 60)
        c = rnd.choice(cols)
        kind = rnd.random()
        s = rnd.uniform(14, 30)
        if kind < 0.4:
            d.ellipse((x - s, y - s, x + s, y + s), fill=c)
        elif kind < 0.7:
            sparkle(d, x, y, s * 2.0, c)
        else:
            w = s * 0.6
            d.rounded_rectangle((x - s * 1.6, y - w, x + s * 1.6, y + w), radius=w, fill=c)
            d.rounded_rectangle((x - w, y - s * 1.6, x + w, y + s * 1.6), radius=w, fill=c)


def shadow_paste(img, layer, x, y, blur=46, offset=34, alpha=90):
    a = layer.split()[3]
    sh = Image.new("RGBA", layer.size, (20, 50, 20, 0))
    sh.putalpha(a.point(lambda v: v * alpha // 255))
    pad = blur * 3
    big = Image.new("RGBA", (layer.width + 2 * pad, layer.height + 2 * pad), (0, 0, 0, 0))
    big.paste(sh, (pad, pad))
    big = big.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(big, (int(x - pad), int(y - pad + offset)))
    img.alpha_composite(layer, (int(x), int(y)))


def phone_layer(path, h, crop_bottom=0.0):
    shot = Image.open(path).convert("RGB")
    if crop_bottom:
        shot = shot.crop((0, 0, shot.width, int(shot.height * (1 - crop_bottom))))
    w = int(shot.width * h / Image.open(path).height)
    sh_h = int(shot.height * h / Image.open(path).height)
    shot = shot.resize((w, sh_h), Image.LANCZOS)
    bez = 24
    layer = Image.new("RGBA", (w + 2 * bez, h + 2 * bez), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((0, 0, layer.width - 1, layer.height - 1), radius=128, fill=(28, 28, 30, 255))
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w, h), radius=106, fill=255)
    screen = Image.new("RGB", (w, h), (242, 242, 247))
    screen.paste(shot, (0, 0))
    layer.paste(screen, (bez, bez), m)
    return layer


def place(img, layer, cx, top, angle):
    r = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    shadow_paste(img, r, cx - r.width / 2, top - (r.height - layer.height) / 2)


def card(w, h, radius=48, fill=WHITE):
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=fill + (255,))
    return layer


def sticker(text, amount=None, dot=ORANGE, size=54):
    f = font(size, "Bold")
    af = font(size - 6, "Heavy")
    tmp = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    tw = tmp.textlength(text, font=f)
    aw = tmp.textlength(amount, font=af) + 56 if amount else 0
    w, h = int(150 + tw + aw + (30 if amount else 0)), int(size * 2.6)
    layer = card(w, h, radius=h // 2)
    d = ImageDraw.Draw(layer)
    d.ellipse((50, h / 2 - 17, 84, h / 2 + 17), fill=dot)
    d.text((114, h / 2), text, font=f, fill=INK, anchor="lm")
    if amount:
        x0 = w - aw - 34
        d.rounded_rectangle((x0, h / 2 - size * 0.72, w - 34, h / 2 + size * 0.72), radius=size, fill=LIME_SOFT)
        d.text((x0 + aw / 2, h / 2), amount, font=af, fill=LIME_DEEP, anchor="mm")
    return layer


def bubble(label, text, fill, label_col, text_col, width=760):
    lf, tf = font(36, "Heavy"), font(52, "Semibold")
    tmp = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    lines = wrap(tmp, text, tf, width - 110)
    h = 120 + len(lines) * 68 + 40
    layer = card(width, h, radius=60, fill=fill)
    d = ImageDraw.Draw(layer)
    d.text((56, 50), label, font=lf, fill=label_col)
    y = 112
    for ln in lines:
        d.text((56, y), ln, font=tf, fill=text_col)
        y += 68
    return layer


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


def headline(d, x0, l1, l2, sub):
    """Two-line headline; the second line sits on a lime marker stroke."""
    f = font(116, "Heavy")
    cx = x0 + W / 2
    d.text((cx, 250), l1, font=f, fill=INK, anchor="mm")
    w2 = d.textlength(l2, font=f)
    d.rounded_rectangle((cx - w2 / 2 - 30, 330, cx + w2 / 2 + 30, 440), radius=40, fill=LIME)
    d.text((cx, 385), l2, font=f, fill=INK, anchor="mm")
    sf = font(54, "Medium")
    y = 520
    for ln in wrap(d, sub, sf, W - 240):
        d.text((cx, y), ln, font=sf, fill=SUB, anchor="mm")
        y += 72


def bill_paper(angle):
    """A cartoon itemized bill with one line circled."""
    w, h = 560, 720
    layer = card(w, h, radius=36)
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((0, 0, w - 1, 120), radius=36, fill=(236, 241, 236))
    d.rectangle((0, 80, w - 1, 120), fill=(236, 241, 236))
    d.text((48, 58), "STATEMENT", font=font(40, "Heavy"), fill=INK, anchor="lm")
    y = 170
    rows = [0.62, 0.5, 0.7, 0.55, 0.66, 0.48]
    for i, k in enumerate(rows):
        d.rounded_rectangle((48, y, 48 + (w - 230) * k, y + 26), radius=13, fill=(205, 214, 205))
        d.rounded_rectangle((w - 150, y, w - 48, y + 26), radius=13, fill=(205, 214, 205))
        if i in (1, 2):
            d.rounded_rectangle((26, y - 22, w - 26, y + 48), radius=35, outline=ORANGE, width=8)
        y += 82
    d.line((48, y + 10, w - 48, y + 10), fill=(205, 214, 205), width=6)
    d.text((48, y + 66), "TOTAL", font=font(40, "Heavy"), fill=INK, anchor="lm")
    d.rounded_rectangle((w - 200, y + 50, w - 48, y + 82), radius=16, fill=RED)
    return layer.rotate(angle, resample=Image.BICUBIC, expand=True)


def magnifier(r=150):
    s = int(r * 3.2)
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = r + 30
    d.line((c + r * 0.7, c + r * 0.7, s - 40, s - 40), fill=INK, width=52)
    d.ellipse((c - r, c - r, c + r, c + r), fill=(255, 255, 255, 120), outline=INK, width=34)
    d.arc((c - r * 0.65, c - r * 0.65, c + r * 0.65, c + r * 0.65), 200, 260, fill=WHITE, width=18)
    return layer


def letter_paper():
    w, h = 1000, 1420
    layer = card(w, h, radius=40)
    d = ImageDraw.Draw(layer)
    f = font(34, "Regular", MONO)
    fb = font(34, "Bold", MONO)
    text = [
        ("Billing Department", f), ("", f),
        ("Re: Request for billing review", fb), ("", f),
        ("To whom it may concern,", f), ("", f),
    ]
    body = ("I have reviewed the statement referenced above and would like the "
            "following items verified and, where appropriate, corrected before I "
            "make payment:")
    tmp = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    text += [(ln, f) for ln in wrap(tmp, body, f, w - 140)] + [("", f)]
    text += [(ln, fb) for ln in wrap(tmp, "1. Possible duplicate charge.", fb, w - 140)]
    text += [(ln, f) for ln in wrap(tmp, "Ask billing to verify that each instance of "
                                    "this charge corresponds to a distinct service.", f, w - 140)]
    text += [("", f)]
    text += [(ln, fb) for ln in wrap(tmp, "2. Line items add up to more than the stated total.", fb, w - 140)]
    text += [("", f), ("Thank you for your assistance.", f), ("", f), ("Sincerely,", f)]
    y = 80
    for ln, ff in text:
        d.text((70, y), ln, font=ff, fill=(40, 52, 42))
        y += 50
    return layer


def envelope(w=880, h=560):
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=44, fill=LIME + (255,))
    d.polygon([(0, 40), (w / 2, h * 0.62), (w, 40), (w, 0), (0, 0)], fill=LIME_DEEP + (255,))
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=44, outline=LIME_DEEP + (255,), width=6)
    return layer


def badge(icon_draw, text, w=520):
    h = 150
    layer = card(w, h, radius=75)
    d = ImageDraw.Draw(layer)
    d.ellipse((24, 24, 126, 126), fill=LIME_SOFT)
    icon_draw(d, 75, 75)
    d.text((150, h / 2), text, font=font(50, "Bold"), fill=INK, anchor="lm")
    return layer


def ic_lock(d, cx, cy):
    d.arc((cx - 22, cy - 40, cx + 22, cy + 4), 180, 360, fill=LIME_DEEP, width=10)
    d.rounded_rectangle((cx - 32, cy - 14, cx + 32, cy + 34), radius=10, fill=LIME_DEEP)


def ic_cloud_off(d, cx, cy):
    d.ellipse((cx - 36, cy - 10, cx + 4, cy + 26), fill=LIME_DEEP)
    d.ellipse((cx - 14, cy - 30, cx + 30, cy + 14), fill=LIME_DEEP)
    d.rounded_rectangle((cx - 36, cy + 4, cx + 36, cy + 26), radius=11, fill=LIME_DEEP)
    d.line((cx - 38, cy - 34, cx + 38, cy + 38), fill=LIME_SOFT, width=14)
    d.line((cx - 38, cy - 34, cx + 38, cy + 38), fill=LIME_DEEP, width=7)


def ic_plane(d, cx, cy):
    d.polygon([(cx - 6, cy - 40), (cx + 6, cy - 40), (cx + 8, cy + 34), (cx - 8, cy + 34)], fill=LIME_DEEP)
    d.polygon([(cx - 40, cy + 6), (cx + 40, cy + 6), (cx + 6, cy - 14), (cx - 6, cy - 14)], fill=LIME_DEEP)
    d.polygon([(cx - 20, cy + 36), (cx + 20, cy + 36), (cx + 6, cy + 24), (cx - 6, cy + 24)], fill=LIME_DEEP)


def ic_person_off(d, cx, cy):
    d.ellipse((cx - 16, cy - 36, cx + 16, cy - 4), fill=LIME_DEEP)
    d.rounded_rectangle((cx - 32, cy + 2, cx + 32, cy + 38), radius=18, fill=LIME_DEEP)
    d.line((cx - 38, cy - 34, cx + 38, cy + 38), fill=LIME_SOFT, width=14)
    d.line((cx - 38, cy - 34, cx + 38, cy + 38), fill=LIME_DEEP, width=7)


def render(out):
    img = gradient().convert("RGBA")
    ribbon(img)
    confetti(img)
    d = ImageDraw.Draw(img)
    X = [i * W for i in range(N)]

    # 1. Hero
    headline(d, X[0], "Check your bill", "before you pay.",
             "Snap a photo. See what's worth asking about, in seconds.")
    place(img, phone_layer(os.path.join(LIGHT, "results.png"), 1980), X[0] + 700, 830, 4)
    # bill + magnifier straddle panels 1 and 2
    bp = bill_paper(-12)
    shadow_paste(img, bp, X[1] - bp.width / 2 - 60, 2240)
    mg = magnifier()
    img.alpha_composite(mg, (int(X[1] - 170), 2440))
    s = sticker("1 week free", dot=LIME, size=58).rotate(8, resample=Image.BICUBIC, expand=True)
    shadow_paste(img, s, X[0] + 90, 1060)

    # 2. Findings
    headline(d, X[1], "Catch charges", "worth questioning.",
             "Duplicates, totals that don't add up, vague fees.")
    place(img, phone_layer(os.path.join(LIGHT, "checklist.png"), 1900), X[1] + 760, 860, -5)
    for i, (t, a, c, ang) in enumerate([
            ("Same charge twice", "$150", ORANGE, 4),
            ("Doesn't add up", "$150", RED, -3),
            ("Vague \"misc supplies\"", "$340", ORANGE, 3),
            ("Tests billed separately", "$120", ORANGE, -4)]):
        st = sticker(t, a, dot=c, size=50).rotate(ang, resample=Image.BICUBIC, expand=True)
        shadow_paste(img, st, X[1] + 40 + (i % 2) * 70, 1180 + i * 250)

    # 3. What to say
    headline(d, X[2], "Know exactly", "what to say.",
             "The question to ask billing, and what to say if they push back.")
    place(img, phone_layer(os.path.join(LIGHT, "finding.png"), 1900), X[2] + 520, 860, -5)
    b1 = bubble("THEY MAY SAY", "The service was performed twice.",
                WHITE, (142, 142, 147), INK, 700).rotate(3, resample=Image.BICUBIC, expand=True)
    shadow_paste(img, b1, X[2] + 560, 1500)
    b2 = bubble("YOU CAN SAY", "Then please point to each one separately in my medical record.",
                LIME, INK, INK, 760).rotate(-3, resample=Image.BICUBIC, expand=True)
    shadow_paste(img, b2, X[2] + 500, 1900)

    # 4. Letter (envelope pokes back into panel 3)
    headline(d, X[3], "The letter,", "written for you.",
             "Polite and clear. It asks billing to check. It never accuses.")
    env = envelope().rotate(10, resample=Image.BICUBIC, expand=True)
    shadow_paste(img, env, X[3] - 260, 2150)
    lp = letter_paper().rotate(-4, resample=Image.BICUBIC, expand=True)
    shadow_paste(img, lp, X[3] + (W - lp.width) / 2, 820)
    s = sticker("Ready to send", dot=LIME, size=58).rotate(-6, resample=Image.BICUBIC, expand=True)
    shadow_paste(img, s, X[3] + 640, 2260)

    # 5. Private + trial
    headline(d, X[4], "Your bill never", "leaves your phone.",
             "Try Pro free for a week, then $2.99/month.")
    place(img, phone_layer(os.path.join(LIGHT, "home.png"), 1900), X[4] + 820, 880, 5)
    for i, (ic, t) in enumerate([(ic_person_off, "No account"), (ic_cloud_off, "No upload"),
                                 (ic_plane, "Works offline"), (ic_lock, "On-device")]):
        bg = badge(ic, t, 520).rotate((-1) ** i * 3, resample=Image.BICUBIC, expand=True)
        shadow_paste(img, bg, X[4] + 50, 1180 + i * 240)

    os.makedirs(out, exist_ok=True)
    full = img.convert("RGB")
    full.resize((PW // 5, H // 5), Image.LANCZOS).save(os.path.join(out, "panorama-preview.png"))
    for i in range(N):
        full.crop((i * W, 0, (i + 1) * W, H)).save(os.path.join(out, f"{i + 1:02d}.png"))


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "appstore")
