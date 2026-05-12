# rankings_2 — sprite map

Source: `rankings_2.png` (1448 × 1086) → split into `rankings_2/` via `_tools/img_split.py`. Reference: `rankings_2_sheet.png`.

Background: near-uniform white (253–255 range). Knocked out with `--bg "#FFFFFF" --tolerance 8`.

## Files

### Rank tiers (8)
| File | Notes |
|------|-------|
| `SSS.png` | gold "SSS" with crown — purple shield, top tier |
| `SS.png` | gold "SS" with star — purple shield with gold wings |
| `S_plus.png` | gold "S+" — red/burgundy shield with gold wings |
| `S.png` | gold "S" — brown shield with gold wings |
| `A.png` | pink "A" — purple shield with white wings |
| `B.png` | blue "B" — dark blue shield with ribbons |
| `C.png` | green "C" — green shield with rivets |
| `D.png` | grey "D" — charcoal shield |

### Detached sparkle decorations (4)
| File | Size | Notes |
|------|------|-------|
| `sparkle_1.png` | 21×24 | small yellow 4-point star |
| `sparkle_2.png` | 20×24 | small yellow 4-point star |
| `sparkle_3.png` | 32×33 | larger yellow 4-point star |
| `sparkle_4.png` | 32×32 | larger yellow 4-point star |

These are the floating sparkle effects placed around the top-row S-tier badges. They didn't merge with their parent badges via 8-connectivity. If you want each rank's sparkles baked in, composite them onto the matching badge or paint a 1-px connector in the source and re-split.

## Rebuild from scratch

```
py _tools/img_split.py assets/rankings_2.png --bg "#FFFFFF" --tolerance 8 --min-area 100 -o assets/rankings_2
```
