#!/usr/bin/env python3
"""Render Lime Shield social slides (1080x1350) from a JSON spec.

Matches the house style of social/carousel-v2: near-black background with a
soft lime glow, "LIME SHIELD" label, heavy white headline, grey body text,
lime highlights, page counter on multi-slide posts.

Usage:
    python3 render_slides.py spec.json OUTPUT_DIR

Spec:
{
  "slides": [
    {"headline": "Your bill is mostly codes.",
     "body": "Here's how to read one in 60 seconds.",
     "highlight": ["60 seconds"],          # words drawn in lime (optional)
     "bullets": ["Ask for the itemized bill", "..."],   # optional
     "image": "../devpost/02-finding.png",  # optional screenshot, path relative to spec
     "cta": "Free on the App Store"}        # optional lime pill at the bottom
  ]
}
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1080, 1350
MARGIN = 72
BG = (13, 15, 18)
LIME = (132, 204, 22)
WHITE = (245, 246, 247)
GREY = (160, 164, 170)
PILL_BG = (30, 42, 14)

FONT_FILE = "/System/Library/Fonts/SFNS.ttf"
FALLBACK = "/System/Library/Fonts/HelveticaNeue.ttc"


def font(size, weight="Regular"):
    try:
        f = ImageFont.truetype(FONT_FILE, size)
        try:
            f.set_variation_by_name(weight)
        except Exception:
            pass
        return f
    except OSError:
        return ImageFont.truetype(FALLBACK, size, index=1 if weight != "Regular" else 0)


def background():
    img = Image.new("RGB", (W, H), BG)
    glow = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(glow)
    d.ellipse((W * 0.45, -H * 0.35, W * 1.5, H * 0.45), fill=(34, 52, 14))
    d.ellipse((-W * 0.6, H * 0.7, W * 0.5, H * 1.4), fill=(22, 34, 10))
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    return Image.blend(img, glow, 0.9)


def wrap(draw, text, fnt, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=fnt) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def draw_rich_line(draw, x, y, line, fnt, base, highlights):
    """Draw a line, colouring any word that is part of a highlight phrase."""
    lit = set()
    lower = line.lower()
    for phrase in highlights:
        start = lower.find(phrase.lower())
        while start != -1:
            lit.update(range(start, start + len(phrase)))
            start = lower.find(phrase.lower(), start + 1)
    cursor, i = x, 0
    for word in line.split(" "):
        colour = LIME if any(j in lit for j in range(i, i + len(word))) else base
        draw.text((cursor, y), word, font=fnt, fill=colour)
        cursor += draw.textlength(word + " ", font=fnt)
        i += len(word) + 1


def _text_block_height(d, slide):
    h = 0
    if slide.get("headline"):
        f = font(104, "Heavy")
        h += len(wrap(d, slide["headline"], f, W - 2 * MARGIN)) * int(104 * 1.08) + 30
    if slide.get("body"):
        h += len(wrap(d, slide["body"], font(44), W - 2 * MARGIN)) * 58 + 30
    for bullet in slide.get("bullets", []):
        h += len(wrap(d, bullet, font(44, "Medium"), W - 2 * MARGIN - 56)) * 58 + 26
    return h


def render(slide, index, total, base_dir):
    img = background()
    d = ImageDraw.Draw(img)
    hl = slide.get("highlight", [])

    # Label and counter
    d.ellipse((MARGIN, 78, MARGIN + 14, 92), fill=LIME)
    d.text((MARGIN + 26, 66), "LIME SHIELD", font=font(30, "Bold"), fill=LIME)
    if total > 1:
        counter = f"{index} OF {total}"
        f = font(28, "Semibold")
        d.text((W - MARGIN - d.textlength(counter, font=f), 68), counter, font=f, fill=GREY)

    has_image = bool(slide.get("image"))
    if not has_image:
        # Text-only slide: lay out once to measure, then centre the block in the
        # space between the label and the CTA (or the bottom margin).
        probe = ImageDraw.Draw(Image.new("RGB", (W, H)))
        height = _text_block_height(probe, slide)
        space_bottom = H - 80 - (136 if slide.get("cta") else 0)
        y = max(170, 150 + (space_bottom - 150 - height) // 2)
    else:
        y = 170
    head_size = 84 if has_image else 104

    if slide.get("headline"):
        f = font(head_size, "Heavy")
        for line in wrap(d, slide["headline"], f, W - 2 * MARGIN):
            draw_rich_line(d, MARGIN, y, line, f, WHITE, hl)
            y += int(head_size * 1.08)
        y += 30

    if slide.get("body"):
        f = font(44)
        for line in wrap(d, slide["body"], f, W - 2 * MARGIN):
            draw_rich_line(d, MARGIN, y, line, f, GREY, hl)
            y += 58
        y += 30

    for bullet in slide.get("bullets", []):
        f = font(44, "Medium")
        lines = wrap(d, bullet, f, W - 2 * MARGIN - 56)
        d.ellipse((MARGIN + 4, y + 18, MARGIN + 20, y + 34), fill=LIME)
        for line in lines:
            draw_rich_line(d, MARGIN + 56, y, line, f, WHITE, hl)
            y += 58
        y += 26

    bottom = H - 80
    if slide.get("cta"):
        f = font(42, "Semibold")
        tw = d.textlength(slide["cta"], font=f)
        pill_h = 96
        top = bottom - pill_h
        d.rounded_rectangle((MARGIN, top, MARGIN + tw + 72, bottom), radius=pill_h // 2,
                            fill=PILL_BG, outline=(72, 110, 20), width=2)
        d.text((MARGIN + 36, top + 22), slide["cta"], font=f, fill=LIME)
        bottom = top - 40

    if has_image:
        path = os.path.join(base_dir, slide["image"])
        shot = Image.open(path).convert("RGB")
        avail_h = bottom - y
        avail_w = W - 2 * MARGIN
        scale = min(avail_w / shot.width, avail_h / shot.height)
        if scale > 0.05:
            shot = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)
            mask = Image.new("L", shot.size, 0)
            ImageDraw.Draw(mask).rounded_rectangle((0, 0, *shot.size), radius=36, fill=255)
            img.paste(shot, ((W - shot.width) // 2, y), mask)

    return img


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    spec_path, out_dir = sys.argv[1], sys.argv[2]
    with open(spec_path) as fh:
        slides = json.load(fh)["slides"]
    os.makedirs(out_dir, exist_ok=True)
    base_dir = os.path.dirname(os.path.abspath(spec_path))
    for i, slide in enumerate(slides, 1):
        out = os.path.join(out_dir, f"{i:02d}.png")
        render(slide, i, len(slides), base_dir).save(out)
        print(out)


if __name__ == "__main__":
    main()
