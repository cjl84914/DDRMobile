#!/usr/bin/env python3
"""Bake the title-screen backdrop, plus a fallback logo, into assets/title/.

assets/title/logo.png is hand-cut art (see tools/clean_title_logo.py), so this
script leaves it alone unless --logo is passed. The drawing code below is what
produced the earlier placeholder wordmark and is kept as a fallback for machines
without that source image.

The backdrop is a teal-to-violet sparkle field drawn here; no art file and no
font file from a third party is redistributed with the project.

Usage:  python3 tools/make_title_assets.py [--logo]
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "title"

# (path, variation) pairs, most preferred first.
FONT_CANDIDATES = [
    ("/System/Library/Fonts/Supplemental/DIN Alternate Bold.ttf", None),
    ("/System/Library/Fonts/Supplemental/Arial Black.ttf", None),
    ("/System/Library/Fonts/Supplemental/Impact.ttf", None),
]

INK = (18, 18, 20, 255)
PAPER = (255, 255, 255, 255)
PINK = (232, 58, 145, 255)
BLUE = (44, 132, 210, 255)

# Arrow directions, as whole-tile rotation in degrees (PIL rotates counter-clockwise).
UP_LEFT, UP_RIGHT, DOWN_LEFT, DOWN_RIGHT = 45.0, -45.0, 135.0, 225.0


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path, variation in FONT_CANDIDATES:
        if not Path(path).exists():
            continue
        font = ImageFont.truetype(path, size)
        if variation:
            try:
                font.set_variation_by_name(variation)
            except Exception:  # static face, or a non-variable font
                pass
        return font
    raise SystemExit("no heavy rounded font found")


def arrow_mask(size: int, supersample: int = 4) -> Image.Image:
    """A DDR-style arrow pointing up, white on transparent, with soft corners."""
    s = size * supersample
    mask = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(mask)

    def p(x: float, y: float) -> tuple[float, float]:
        return ((x + 1.0) * 0.5 * s, (y + 1.0) * 0.5 * s)

    points = [
        p(0.0, -0.94),
        p(0.74, 0.10),
        p(0.62, 0.26),
        p(0.30, 0.26),
        p(0.30, 0.94),
        p(-0.30, 0.94),
        p(-0.30, 0.26),
        p(-0.62, 0.26),
        p(-0.74, 0.10),
    ]
    d.polygon(points, fill=255)
    mask = mask.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(9))
    mask = mask.filter(ImageFilter.GaussianBlur(s * 0.008))
    return mask.resize((size, size), Image.LANCZOS)


def tile(side: int, colour: tuple[int, int, int, int], angle: float, supersample: int = 3) -> Image.Image:
    """One ink-outlined, white-framed arrow tile, rotated so the arrow aims diagonally."""
    s = side * supersample
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)

    ink = s * 0.048
    band = s * 0.130          # width of the white frame
    radius = s * 0.24

    gap = s * 0.030
    d.rounded_rectangle((ink, ink, s - ink, s - ink), radius=radius, fill=INK)
    d.rounded_rectangle(
        (ink + gap, ink + gap, s - ink - gap, s - ink - gap),
        radius=radius * 0.9,
        fill=PAPER,
    )
    inner = ink + gap + band
    d.rounded_rectangle((inner, inner, s - inner, s - inner), radius=radius * 0.6, fill=colour)

    # A soft top highlight keeps the flat colour from looking like a sticker.
    gloss = Image.new("L", (s, s), 0)
    gd = ImageDraw.Draw(gloss)
    gd.rounded_rectangle((inner, inner, s - inner, s * 0.52), radius=radius * 0.6, fill=54)
    gloss = gloss.filter(ImageFilter.GaussianBlur(s * 0.05))
    sheen = Image.new("RGBA", (s, s), PAPER)
    sheen.putalpha(gloss)
    canvas.alpha_composite(sheen)

    glyph_side = int((s - 2 * inner) * 0.94)
    glyph = arrow_mask(glyph_side, supersample)
    offset = int(inner + (s - 2 * inner - glyph_side) / 2)
    canvas.paste(Image.new("RGBA", glyph.size, PAPER), (offset, offset), glyph)

    canvas = canvas.rotate(angle, resample=Image.BICUBIC, expand=True)
    return canvas.resize((int(canvas.width / supersample), int(canvas.height / supersample)), Image.LANCZOS)


def outlined_text(canvas: Image.Image, text: str, font: ImageFont.FreeTypeFont,
                  xy: tuple[int, int], stroke: int, shear: float = 0.0) -> None:
    """White letters with a heavy ink outline, slight italic shear, soft drop shadow."""
    pad = stroke + 60
    w = int(font.getlength(text)) + pad * 2
    h = int(font.size * 1.6) + pad * 2
    layer = Image.new("RGBA", (w + int(abs(shear) * h), h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((pad, pad), text, font=font, fill=PAPER, stroke_width=stroke, stroke_fill=INK)
    if shear:
        layer = layer.transform(
            layer.size, Image.AFFINE, (1, shear, -shear * layer.height * 0.5, 0, 1, 0), resample=Image.BICUBIC
        )
    shade = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    shade.putalpha(layer.getchannel("A").filter(ImageFilter.GaussianBlur(9)).point(lambda v: int(v * 0.40)))
    canvas.alpha_composite(shade, (xy[0] - pad + 8, xy[1] - pad + 12))
    canvas.alpha_composite(layer, (xy[0] - pad, xy[1] - pad))


def build_logo() -> Image.Image:
    """Arrow cluster on the left, one hard-edged "DDRMobile" wordmark on the right.

    The cluster and the wordmark are laid out independently and then joined on a
    shared baseline, so the tile sizes can change without re-tuning magic pixel
    offsets for the text.
    """
    font = load_font(330)
    stroke = 50
    text = Image.new("RGBA", (3000, 900), (0, 0, 0, 0))
    outlined_text(text, "DDRMobile", font, (820, 300), stroke=stroke, shear=0.05)
    text_box = text.getchannel("A").getbbox()
    text = text.crop(text_box)

    # Four tiles overlapping into one tight diagonal chain, not four separate
    # badges: neighbours now share about a fifth of their edge.
    cluster = Image.new("RGBA", (1000, 1000), (0, 0, 0, 0))
    cx, cy = 500, 500
    k = 0.66
    for ox, oy, side, colour, angle in [
        (-118, -122, 240, PINK, UP_LEFT),
        (+120, -132, 300, BLUE, UP_RIGHT),
        (-134, +118, 288, BLUE, DOWN_LEFT),
        (+112, +126, 312, PINK, DOWN_RIGHT),
    ]:
        ox, oy, side = int(ox * k), int(oy * k), int(side * k)
        img = tile(side, colour, angle)
        cluster.alpha_composite(img, (cx + ox - img.width // 2, cy + oy - img.height // 2))
    cluster = cluster.crop(cluster.getchannel("A").getbbox())

    gap = 34
    width = cluster.width + gap + text.width
    height = max(cluster.height, text.height)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.alpha_composite(cluster, (0, (height - cluster.height) // 2))
    canvas.alpha_composite(text, (cluster.width + gap, (height - text.height) // 2))

    canvas = _add_white_halo(canvas, radius=max(8, int(min(width, height) * 0.016)))
    return canvas.crop(canvas.getchannel("A").getbbox())


def _add_white_halo(canvas: Image.Image, radius: int) -> Image.Image:
    """Wrap the whole mark (tiles and lettering) in a white outline.

    The arcade logo separates itself from the busy background with a white rim
    outside the black keyline. Only near-opaque pixels seed the rim, and the rim
    is painted over the drop shadow so the shadow cannot muddy it into grey.
    """
    alpha = np.array(canvas.getchannel("A")).astype(np.int16)
    solid = Image.fromarray(((alpha >= 200) * 255).astype(np.uint8))
    # A blurred step crosses the 12% level at roughly 1.17 sigma, so this keeps
    # the requested rim width instead of letting it shrink with the blur.
    grown = solid.filter(ImageFilter.GaussianBlur(radius / 1.17))
    reach = np.array(grown) > 30
    ring = (reach & (alpha < 200)).astype(np.uint8) * 255
    # Feather the rim edge only, so it stays a crisp line instead of a glow.
    ring = np.array(Image.fromarray(ring).filter(ImageFilter.GaussianBlur(0.7)))
    halo = Image.new("RGBA", canvas.size, (255, 255, 255, 0))
    halo.putalpha(Image.fromarray(ring))
    return Image.alpha_composite(canvas, halo)


def _smooth_path(points: list[tuple[float, float]], steps: int = 24) -> list[tuple[float, float]]:
    """Catmull-Rom through the control points, so ribbons read as curls."""
    if len(points) < 3:
        return points
    pts = [points[0]] + points + [points[-1]]
    out: list[tuple[float, float]] = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t
                       + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t
                       + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    return out


def build_background() -> Image.Image:
    W, H = 2560, 1440
    rng = random.Random(2014)

    xs = np.linspace(0.0, 1.0, W)[None, :]
    ys = np.linspace(0.0, 1.0, H)[:, None]

    top = np.array([86, 214, 199], float)
    mid = np.array([40, 148, 226], float)
    low = np.array([34, 78, 190], float)
    violet = np.array([124, 92, 214], float)

    t = np.clip(ys * 0.70 + xs * 0.26, 0.0, 1.0)
    early = t < 0.52
    u = np.where(early, t / 0.52, (t - 0.52) / 0.48)[..., None]
    a = np.where(early[..., None], top, mid)
    b = np.where(early[..., None], mid, low)
    rgb = a + (b - a) * u

    # Violet wash filling the upper right, as in the arcade backdrop.
    v = (np.clip((xs - 0.38) / 0.62, 0, 1) ** 1.4) * (np.clip(1.0 - ys * 1.15, 0, 1)) * 0.72
    rgb = rgb + (violet - rgb) * v[..., None]

    # Bright cyan flare rising from the lower left.
    gx = (xs - 0.14) / 0.50
    gy = (ys - 1.04) / 0.42
    flare = np.clip(1.0 - np.sqrt(gx * gx + gy * gy), 0.0, 1.0) ** 1.5
    rgb = rgb + (np.array([236, 252, 252], float) - rgb) * (flare * 0.80)[..., None]

    # A weaker bloom in the upper right, where the logo sits.
    gx = (xs - 0.78) / 0.34
    gy = (ys - 0.06) / 0.30
    bloom = np.clip(1.0 - np.sqrt(gx * gx + gy * gy), 0.0, 1.0) ** 2.0
    rgb = rgb + (np.array([224, 220, 250], float) - rgb) * (bloom * 0.45)[..., None]

    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

    ribbons = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ribbons)
    for _ in range(16):
        x0, y0 = rng.uniform(-0.1, 1.1) * W, rng.uniform(-0.1, 1.1) * H
        pts = [(x0, y0)]
        ang = rng.uniform(-math.pi, math.pi)
        for _ in range(rng.randint(3, 4)):
            ang += rng.uniform(-1.0, 1.0)
            step = rng.uniform(140, 340)
            x0 += math.cos(ang) * step
            y0 += math.sin(ang) * step
            pts.append((x0, y0))
        rd.line(_smooth_path(pts), fill=(255, 255, 255, rng.randint(26, 52)),
                width=rng.randint(10, 26), joint="curve")
    img = Image.alpha_composite(img, ribbons.filter(ImageFilter.GaussianBlur(7.0)))

    dots = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dots)
    for _ in range(420):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(1.0, 4.0)
        dd.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, rng.randint(80, 200)))
    for _ in range(80):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r, a = rng.uniform(3.0, 11.0), rng.randint(90, 200)
        dd.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, a // 3))
        dd.ellipse((x - r * 0.4, y - r * 0.4, x + r * 0.4, y + r * 0.4), fill=(255, 255, 255, a))
    for _ in range(52):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        arm, thin = rng.uniform(8, 32), 0.11
        a = rng.randint(170, 250)
        dd.polygon([(x, y - arm), (x + arm * thin, y - arm * thin), (x + arm, y),
                    (x + arm * thin, y + arm * thin), (x, y + arm),
                    (x - arm * thin, y + arm * thin), (x - arm, y),
                    (x - arm * thin, y - arm * thin)], fill=(255, 255, 255, a))
    img = Image.alpha_composite(img, dots.filter(ImageFilter.GaussianBlur(0.7)))

    return img.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if "--logo" in sys.argv:
        logo = build_logo()
        logo.save(OUT / "logo.png", optimize=True)
        print("logo", logo.size, "->", OUT / "logo.png")
    else:
        print("logo kept:", OUT / "logo.png", "(hand-cut; pass --logo to redraw)")
    bg = build_background()
    bg.save(OUT / "backdrop.jpg", quality=90, optimize=True, progressive=True)
    print("backdrop", bg.size, "->", OUT / "backdrop.jpg")


if __name__ == "__main__":
    main()
