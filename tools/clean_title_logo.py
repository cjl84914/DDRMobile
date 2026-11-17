#!/usr/bin/env python3
"""Clean a hand-cut title logo and write it to assets/title/logo.png.

The logo shipped in this project was cut out of a Dance Dance Revolution 2014
title-screen capture by hand, so it arrives with two defects: anti-aliased edge
pixels still carry the cyan background it was lifted from, and the mask is
stair-stepped from a magic-wand selection. Both are cheap to fix offline:

  * semi-transparent pixels are pulled toward white, matching the logo's own
    white rim, instead of leaving a cyan halo on the darker parts of the
    backdrop;
  * the result is scaled 2x with Lanczos and the alpha edge is feathered, so the
    stair steps disappear once Godot draws it at 1088 design pixels.

Usage:  python3 tools/clean_title_logo.py [source.png]
        (default source: ~/Downloads/banner.png)
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "title" / "logo.png"
DEFAULT_SOURCE = Path.home() / "Downloads" / "banner.png"

# Below this alpha a pixel still carries too much of the old background to keep.
FRINGE_FLOOR = 250


def clean(source: Path) -> Image.Image:
    art = Image.open(source).convert("RGBA")
    data = np.array(art).astype(np.float32)
    alpha = data[:, :, 3:4] / 255.0

    # Weight the pull toward white by how transparent the pixel is: fully opaque
    # ink is untouched, faint edge pixels become the logo's own white outline.
    bleed = np.clip(1.0 - alpha, 0.0, 1.0) ** 1.2
    rgb = data[:, :, :3] * (1.0 - bleed) + 255.0 * bleed
    data = np.dstack([rgb, data[:, :, 3:4]]).clip(0, 255).astype(np.uint8)

    art = Image.fromarray(data, "RGBA").filter(ImageFilter.GaussianBlur(0.4))

    # Drop the stray specks the selection left behind, then square off the frame.
    solid = art.getchannel("A").point(lambda v: 255 if v > 24 else 0)
    box = solid.getbbox()
    if box is not None:
        art = art.crop(box)

    art = art.resize((art.width * 2, art.height * 2), Image.LANCZOS)

    # Feather just the outer edge so the magic-wand stair steps stop showing at
    # display size; interior edges are already antialiased by the upscale.
    alpha = art.getchannel("A").filter(ImageFilter.GaussianBlur(0.6))
    art = art.copy()
    art.putalpha(alpha)
    return art


def main() -> None:
    source = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else DEFAULT_SOURCE
    if not source.exists():
        raise SystemExit(f"source not found: {source}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    logo = clean(source)
    logo.save(OUT, optimize=True)
    print(f"logo {logo.size} -> {OUT}")


if __name__ == "__main__":
    main()
