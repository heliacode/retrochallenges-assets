# HUD asset attribution

| File | Source | License |
|---|---|---|
| `bar_frame.png` | Generated programmatically with ffmpeg (`drawbox` thin outline). 64×8, transparent inner. | Original — public domain |
| `medal_1.png`, `medal_2.png`, `medal_3.png` | Derived from Kenney's [Game Icons](https://kenney.nl/assets/game-icons) pack. Downscaled to 24×24 nearest-neighbour from the white-on-transparent `medal1.png` / `medal2.png` set. | CC0 |

## Still missing

These currently fall back to `gui.text` / `gui.drawRectangle` in `RcHud`:

- `heart_full.png`, `heart_empty.png` — pixel-art heart sprites for the lives row. Kenney's 1-Bit Pack tilesheet has these but they're packed into a single 832×373 sheet that needs cropping by tile coordinates. A standalone CC0 heart pack would land here trivially.
- `strip_top.png` — full-width 256×32 HUD strip background.

## Regen recipes

```bash
# bar_frame.png — 64x8 transparent with a thin slate-blue outline
ffmpeg -y -f lavfi -i color=color=black@0:size=64x8,format=rgba \
    -vf "drawbox=0:0:64:8:0xa0cbd5e1:t=1" -frames:v 1 assets/hud/bar_frame.png

# medals — downscale Kenney game-icons medal1..3 to 24x24 nearest-neighbour
for n in 1 2 3; do
  ffmpeg -y -i path/to/kenney_game-icons/PNG/White/1x/medal${n}.png \
      -vf "scale=24:24:flags=neighbor" assets/hud/medal_${n}.png
done
```
