"""
Remove a solid background color from a PNG and optionally split the remaining
shapes into individual cropped PNGs (one per connected component).

Usage:
    py _tools/img_split.py INPUT.png [-o OUTDIR]
                                     [--bg COLOR] [--tolerance N]
                                     [--min-area N] [--connectivity 4|8]
                                     [--no-split] [--padding N]

Examples:
    # Auto-detect bg from corners, split into shape_001.png ...
    py _tools/img_split.py assets/font_1.png

    # Specific bg color, write to custom dir
    py _tools/img_split.py sheet.png --bg "#FF00FF" -o sheet_glyphs

    # Just strip the background, do not split
    py _tools/img_split.py sheet.png --no-split -o sheet_transparent.png
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def parse_color(s: str) -> tuple[int, int, int]:
    s = s.strip().lstrip("#")
    if len(s) == 3:
        s = "".join(c * 2 for c in s)
    if len(s) != 6:
        raise argparse.ArgumentTypeError(f"bad color {s!r}, expected #RRGGBB")
    return tuple(int(s[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def detect_bg(rgb: np.ndarray) -> tuple[int, int, int]:
    """Pick the background color by majority vote of the four corners,
    falling back to the most common pixel in the image if corners disagree."""
    h, w = rgb.shape[:2]
    corners = [tuple(rgb[0, 0]), tuple(rgb[0, w - 1]),
               tuple(rgb[h - 1, 0]), tuple(rgb[h - 1, w - 1])]
    counts = Counter(corners)
    color, n = counts.most_common(1)[0]
    if n >= 2:
        return color  # type: ignore[return-value]
    flat = rgb.reshape(-1, 3)
    counts = Counter(map(tuple, flat))
    return counts.most_common(1)[0][0]  # type: ignore[return-value]


def strip_background(
    img: Image.Image,
    bgs: list[tuple[int, int, int]] | None,
    tolerance: int,
) -> tuple[Image.Image, np.ndarray, list[tuple[int, int, int]]]:
    """Return (rgba_image, foreground_mask, bg_colors_used).

    Pixels matching ANY of the bg colors (within tolerance) are treated as
    background and made transparent.
    """
    rgb = np.array(img.convert("RGB"))
    if not bgs:
        # If the source had alpha, treat anything already transparent as bg.
        if img.mode == "RGBA":
            alpha = np.array(img.split()[-1])
            mask = alpha > 0
            rgba = np.dstack([rgb, np.where(mask, 255, 0).astype(np.uint8)])
            return Image.fromarray(rgba, "RGBA"), mask, [(0, 0, 0)]
        bgs = [detect_bg(rgb)]

    rgb_i = rgb.astype(np.int16)
    bg_mask = np.zeros(rgb.shape[:2], dtype=bool)
    for bg in bgs:
        target = np.array(bg, dtype=np.int16)
        diff = np.abs(rgb_i - target).max(axis=2)
        bg_mask |= (diff <= tolerance)
    mask = ~bg_mask
    rgba = np.dstack([rgb, np.where(mask, 255, 0).astype(np.uint8)])
    return Image.fromarray(rgba, "RGBA"), mask, bgs


def split_shapes(
    rgba: Image.Image,
    mask: np.ndarray,
    out_dir: Path,
    min_area: int,
    connectivity: int,
    padding: int,
) -> int:
    structure = np.ones((3, 3), dtype=bool) if connectivity == 8 else None
    labels, n = ndimage.label(mask, structure=structure)
    if n == 0:
        return 0

    rgba_arr = np.array(rgba)
    h, w = mask.shape
    out_dir.mkdir(parents=True, exist_ok=True)

    slices = ndimage.find_objects(labels)
    kept = 0
    digits = max(3, len(str(n)))
    for idx, sl in enumerate(slices, start=1):
        if sl is None:
            continue
        component = labels[sl] == idx
        area = int(component.sum())
        if area < min_area:
            continue

        y_slice, x_slice = sl
        y0 = max(0, y_slice.start - padding)
        y1 = min(h, y_slice.stop + padding)
        x0 = max(0, x_slice.start - padding)
        x1 = min(w, x_slice.stop + padding)
        crop = rgba_arr[y0:y1, x0:x1].copy()

        # Zero-out alpha for any pixels that belong to a *different* component
        # within the padded crop, so neighboring shapes do not bleed in.
        local_labels = labels[y0:y1, x0:x1]
        keep = (local_labels == idx)
        crop[..., 3] = np.where(keep, crop[..., 3], 0)

        kept += 1
        out_path = out_dir / f"shape_{kept:0{digits}d}.png"
        Image.fromarray(crop, "RGBA").save(out_path)

    return kept


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("input", type=Path, help="input PNG")
    p.add_argument("-o", "--output", type=Path, default=None,
                   help="output directory (or file, with --no-split). "
                        "Default: <input_stem>_shapes/ next to the input.")
    p.add_argument("--bg", default="auto",
                   help='background color as "#RRGGBB", or comma-separated list '
                        '(e.g. "#000000,#B57A57") to knock out multiple colors, '
                        'or "auto" (default: auto)')
    p.add_argument("--tolerance", type=int, default=8,
                   help="per-channel tolerance 0-255 for matching the bg color (default: 8)")
    p.add_argument("--min-area", type=int, default=4,
                   help="drop components smaller than this many pixels (default: 4)")
    p.add_argument("--connectivity", type=int, choices=(4, 8), default=8,
                   help="pixel connectivity for component labeling (default: 8)")
    p.add_argument("--padding", type=int, default=0,
                   help="extra transparent pixels around each shape's bounding box (default: 0)")
    p.add_argument("--no-split", action="store_true",
                   help="only strip the background, write a single transparent PNG")
    args = p.parse_args(argv)

    if not args.input.is_file():
        print(f"error: input not found: {args.input}", file=sys.stderr)
        return 2

    img = Image.open(args.input)
    if args.bg.lower() == "auto":
        bgs = None
    else:
        bgs = [parse_color(part) for part in args.bg.split(",") if part.strip()]

    rgba, mask, bgs_used = strip_background(img, bgs, args.tolerance)
    bg_str = ", ".join(f"#{r:02X}{g:02X}{b:02X}" for r, g, b in bgs_used)
    print(f"bg color(s): {bg_str}  foreground pixels: {int(mask.sum())} / {mask.size}")

    if args.no_split:
        out = args.output or args.input.with_name(f"{args.input.stem}_nobg.png")
        if out.is_dir():
            out = out / f"{args.input.stem}_nobg.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        rgba.save(out)
        print(f"wrote {out}")
        return 0

    out_dir = args.output or args.input.with_name(f"{args.input.stem}_shapes")
    n = split_shapes(rgba, mask, out_dir, args.min_area, args.connectivity, args.padding)
    print(f"wrote {n} shape(s) to {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
