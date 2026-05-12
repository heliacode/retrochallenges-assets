"""
Build a contact sheet from a directory of split shape PNGs (output of
img_split.py). Each cell shows the filename's shape index above the sprite.
Useful for hand-labeling shapes -> characters/names.

Usage:
    py _tools/img_contact_sheet.py SHAPES_DIR -o OUTPUT.png
                                              [--cell N] [--cols N] [--scale N]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("shapes_dir", type=Path)
    p.add_argument("-o", "--output", type=Path, required=True)
    p.add_argument("--cell", type=int, default=72, help="cell side length in px")
    p.add_argument("--cols", type=int, default=12)
    p.add_argument("--scale", type=int, default=3, help="pixel scale per sprite")
    p.add_argument("--bg", default="#202020")
    args = p.parse_args(argv)

    files = sorted(args.shapes_dir.glob("shape_*.png"))
    if not files:
        print(f"no shape_*.png in {args.shapes_dir}", file=sys.stderr)
        return 2

    cell = args.cell
    label_h = 14
    cols = args.cols
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + label_h)),
                      tuple(int(args.bg.lstrip("#")[i:i+2], 16) for i in (0, 2, 4)) + (255,))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", size=11)
    except OSError:
        font = ImageFont.load_default()

    for i, f in enumerate(files):
        r, c = divmod(i, cols)
        x0 = c * cell
        y0 = r * (cell + label_h)
        idx = f.stem.split("_")[-1]
        draw.text((x0 + 2, y0), idx, fill=(255, 255, 0, 255), font=font)

        sprite = Image.open(f).convert("RGBA")
        w, h = sprite.size
        s = args.scale
        max_w = cell - 4
        max_h = cell - 4
        # fit within cell
        sx = min(s, max_w / max(w, 1), max_h / max(h, 1))
        sx = max(sx, 1)
        nw, nh = int(w * sx), int(h * sx)
        if (nw, nh) != (w, h):
            sprite = sprite.resize((nw, nh), Image.NEAREST)
        ox = x0 + (cell - nw) // 2
        oy = y0 + label_h + (cell - nh) // 2
        sheet.paste(sprite, (ox, oy), sprite)

    sheet.save(args.output)
    print(f"wrote {args.output} ({len(files)} cells, {cols}x{rows})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
