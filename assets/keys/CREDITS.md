# Key glyph attribution

The PNG files in this directory (`k_r.png`, `k_escape.png`, `k_space.png`) are derived from the **Input Prompts** asset pack by Kenney, downscaled from 64×64 to 24×24 with nearest-neighbour for a pixel-art look.

- **Source pack:** Input Prompts 1.4.1 — https://kenney.nl/assets/input-prompts
- **Author:** Kenney — https://www.kenney.nl
- **License:** Creative Commons Zero (CC0) — public domain dedication, no attribution required.

Crediting Kenney is encouraged but not required. We do it here as a courtesy.

To regenerate or add more keys, download the pack and run:

```bash
ffmpeg -y -i "Keyboard & Mouse/Default/keyboard_<name>.png" \
    -vf "scale=24:24:flags=neighbor" \
    assets/keys/k_<name>.png
```
