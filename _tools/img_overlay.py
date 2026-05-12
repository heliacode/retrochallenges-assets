"""
Render an overlay of shape indices on top of the source image, using the same
component-detection logic as img_split.py. Useful for hand-labeling the output
of img_split.py (e.g., mapping shape_NNN.png to characters).

Usage:
    py _tools/img_overlay.py INPUT.png [-o OVERLAY.png]
                                       [--bg COLOR] [--tolerance N]
                                       [--min-area N] [--connectivity 4|8]
                                       [--scale N]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from img_split import detect_bg, parse_color  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("input", type=Path)
    p.add_argument("-o", "--output", type=Path, default=None)
    p.add_argument("--bg", default="auto")
    p.add_argument("--tolerance", type=int, default=8)
    p.add_argument("--min-area", type=int, default=4)
    p.add_argument("--connectivity", type=int, choices=(4, 8), default=8)
    p.add_argument("--scale", type=int, default=3,
                   help="upscale factor so labels are legible (default: 3)")
    args = p.parse_args(argv)

    img = Image.open(args.input).convert("RGB")
    rgb = np.array(img)
    if args.bg.lower() == "auto":
        bgs = [detect_bg(rgb)]
    else:
        bgs = [parse_color(part) for part in args.bg.split(",") if part.strip()]
    rgb_i = rgb.astype(np.int16)
    bg_mask = np.zeros(rgb.shape[:2], dtype=bool)
    for bg in bgs:
        bg_mask |= (np.abs(rgb_i - np.array(bg, dtype=np.int16)).max(axis=2) <= args.tolerance)
    mask = ~bg_mask

    structure = np.ones((3, 3), dtype=bool) if args.connectivity == 8 else None
    labels, n = ndimage.label(mask, structure=structure)
    slices = ndimage.find_objects(labels)

    s = args.scale
    canvas = img.resize((img.width * s, img.height * s), Image.NEAREST).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("arial.ttf", size=max(10, 6 * s))
    except OSError:
        font = ImageFont.load_default()

    kept = 0
    for idx, sl in enumerate(slices, start=1):
        if sl is None:
            continue
        if int((labels[sl] == idx).sum()) < args.min_area:
            continue
        kept += 1
        y_slice, x_slice = sl
        x0, y0 = x_slice.start * s, y_slice.start * s
        x1, y1 = x_slice.stop * s, y_slice.stop * s
        draw.rectangle([x0, y0, x1 - 1, y1 - 1], outline=(0, 255, 0, 255), width=1)
        draw.rectangle([x0, y0, x0 + 7 * s, y0 + 7 * s], fill=(0, 0, 0, 200))
        draw.text((x0 + 1, y0), str(kept), fill=(255, 255, 0, 255), font=font)

    out = args.output or args.input.with_name(f"{args.input.stem}_overlay.png")
    canvas.save(out)
    print(f"labeled {kept} shape(s); wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
