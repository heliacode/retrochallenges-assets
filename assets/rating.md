# rating — sprite map

Source: `rating.png` → split into `rating/` via `_tools/img_split.py`. Reference contact sheet: `rating_sheet.png`.

Background colour: `#3870AF` (solid blue, auto-detected from corners).

## Files

### Rating banners (the actual game sprites)
| File | Notes |
|------|-------|
| `OK.png` | |
| `Good.png` | |
| `Great.png` | |
| `MISS.png` | |
| `Excellent.png` | the "Doesn't exist" ripper annotation overlaps this banner — pixels for the small annotation letters were extracted as separate `annot_*` components, but the residual outline may still touch this sprite. Verify and clean if needed. |
| `LUCKY.png` | |
| `Critical.png` | |
| `TOTAL.png` | |

### Icons
| File | Notes |
|------|-------|
| `mult_x3_a.png` `mult_x3_b.png` `mult_x3_c.png` | "×3" multiplier cards in three variants — verify which colour goes with which. |
| `arrow_red_1.png` `arrow_red_2.png` | red up-arrow icons (likely two frames or a duplicate). |
| `arrow_blue_1.png` `arrow_blue_2.png` | blue up-arrow icons. |

### Watermarks (from whoever ripped the sheet — likely safe to delete)
| File | Notes |
|------|-------|
| `watermark_credit.png` | "Ripped by: MARIO MAKER 69420 / Credit if you want!" block, including the small Mario sprite at the bottom. |
| `watermark_squiggle.png` | "Totally not empty space" cursive scribble. |

### Annotation letter fragments (also from the ripper)
The text "Doesn't exist" was scribbled next to `Excellent.png` and got broken into individual letter components. Naming reflects best-guess letter identity, not source order.

| File | Char |
|------|------|
| `annot_t_1.png` | t |
| `annot_t_2.png` | t |
| `annot_o.png` | o |
| `annot_e_1.png` | e |
| `annot_e_2.png` | e |
| `annot_s_1.png` | s |
| `annot_s_2.png` | s |
| `annot_n.png` | n |
| `annot_x.png` | x |

(Missing: D, ', i. They were either too small to clear `--min-area`, merged with the `Excellent.png` glyph, or merged with each other.)

## Cleanup suggestion

If you only want the playable game sprites, the watermark and annotation files can be deleted in one shot:

```
rm assets/rating/watermark_*.png assets/rating/annot_*.png
```

That leaves the 8 rating banners + 7 icon files = 15 sprites.

## Rebuild from scratch

```
py _tools/img_split.py assets/rating.png -o assets/rating
```
