# rankings — sprite map

Source: `rankings.png` (1254 × 1254) → split into `rankings/` via `_tools/img_split.py`. Reference contact sheet: `rankings_sheet.png`.

Background: white-ish with several near-white shades (240–255 across all channels). Knocked out with `--bg "#FFFFFF" --tolerance 20`.

## Files

### Rank tiers
| File | Notes |
|------|-------|
| `SSS.png` | gold "SSS" with crown and laurel wings |
| `SS.png` | gold "SS" with laurel wreath |
| `S_plus.png` | purple "S+" with built-in sparkles |
| `S.png` | gold "S" with one wing attached |
| `A.png` | green "A" |
| `B.png` | blue "B" |
| `C.png` | silver "C" |
| `D.png` | brown "D" |

### Fragments (detached during split)
| File | Notes |
|------|-------|
| `S_wing.png` | the second wing of `S.png` — didn't merge with the body via 8-connectivity. To get a complete `S` with both wings, composite `S_wing.png` over `S.png` at the appropriate offset, or paint a connecting pixel in the source and re-run. |
| `sparkle.png` | 16 × 15 tiny pixel speck — probably a decorative sparkle that detached from `S_plus.png` (or stray noise). Inspect and delete or composite as needed. |

## Rebuild from scratch

```
py _tools/img_split.py assets/rankings.png --bg "#FFFFFF" --tolerance 20 --min-area 50 -o assets/rankings
```

Note the `--tolerance 20` is required because the source has multiple near-white background shades (`#FEFEFE`, `#F1F1F1`, `#F0F0F0`, `#FDFDFD`, `#FFFFFF`) — a default tolerance of 8 would leave the lighter-grey ones as foreground. The `--min-area 50` filters out anti-aliasing speckle below the body of each rank (without it the split produces dozens of tiny stray pixel components).
