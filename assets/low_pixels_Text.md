# low_pixels_Text — character map

Source: `low_pixels_Text.png` (208 × 64) → split into `low_pixels_Text/` via `_tools/img_split.py`. Reference: `low_pixels_Text_sheet.png`.

Background: two-colour, knocked out together — black (`#000001`) for the text region, tan (`#B57A57`) for the surrounding canvas. The split was run with `--bg "#000001,#B57A57" --tolerance 4`.

The source has 8 visual rows of glyphs:

| Row | y range | Content |
|-----|---------|---------|
| 1 | 0–7   | Bold uppercase A–Z |
| 2 | 8–16  | Punctuation/digits sample: `.` `,` `'` `-` `9` `1` `©` |
| 3 | 17–23 | Thin uppercase A–Z |
| 4 | 25–29 | More small punctuation (5 surviving sprites) |
| 5 | 29–32 | 2 tiny fragments |
| 6 | 33–39 | Digits 0–9 + colon |
| 7 | 41–47 | Block-style "START CLEAR 123" |
| 8 | 48–63 | "Nintendo" + "0123456789E" |

## Naming conventions

- **Row 1 bold uppercase**: bare letter (`A.png` … `Z.png`).
- **Row 3 thin uppercase**: prefixed `thin_` (`thin_A.png` … `thin_Z.png`).
- **Row 7 block-style**: prefixed `block_` (`block_S.png`, `block_T_2.png`, `block_1.png`, …).
- **Row 6 digits**: bare digit (`0.png` … `9.png`); colon split into two dots: `colon_top.png`, `colon_bot.png`.
- **Punctuation** (Windows-safe ASCII names): `period`, `comma`, `apos`, `dash`, `copyright`. Row 2's small `9` and `1` use `_alt` suffix to avoid colliding with the digit row.
- **TODO**: rows 4, 5, 8 — sprites whose identity I couldn't read confidently from the source. They keep numeric placeholders so you can spot them and rename in place.
- **Duplicates** in `block_*` (the second T/A/R in "STARTCLEAR"): suffix `_2`.

## Files

### Row 1 — bold uppercase
`A.png` `B.png` `C.png` `D.png` `E.png` `F.png` `G.png` `H.png` `I.png` `J.png` `K.png` `L.png` `M.png` `N.png` `O.png` `P.png` `Q.png` `R.png` `S.png` `T.png` `U.png` `V.png` `W.png` `X.png` `Y.png` `Z.png`

### Row 2 — punctuation sample
| File | Char |
|------|------|
| `period.png` | `.` |
| `comma.png` | `,` |
| `apos.png` | `'` |
| `dash.png` | `-` |
| `9_alt.png` | `9` (small variant) |
| `1_alt.png` | `1` (small variant) |
| `copyright.png` | `©` |

### Row 3 — thin uppercase
`thin_A.png` `thin_B.png` `thin_C.png` `thin_D.png` `thin_E.png` `thin_F.png` `thin_G.png` `thin_H.png` `thin_I.png` `thin_J.png` `thin_K.png` `thin_L.png` `thin_M.png` `thin_N.png` `thin_O.png` `thin_P.png` `thin_Q.png` `thin_R.png` `thin_S.png` `thin_T.png` `thin_U.png` `thin_V.png` `thin_W.png` `thin_X.png` `thin_Y.png` `thin_Z.png`

### Row 4 — small punctuation (TODO)
| File | Notes |
|------|-------|
| `row4_TODO_1.png` | likely a `.` |
| `row4_TODO_2.png` | likely a `,` |
| `row4_TODO_3.png` | dash-shaped bar |
| `row4_TODO_4.png` | small fragment |
| `row4_TODO_5.png` | small fragment |

Rename these by hand once identified.

### Row 5 — tiny fragments (TODO)
| File | Notes |
|------|-------|
| `row5_TODO_1.png` | tiny dot at left edge |
| `row5_TODO_2.png` | tiny dot at left edge |

Likely descenders of Row 4 chars or fragments below `min_area`. Probably safe to delete.

### Row 6 — digits + colon
`0.png` `1.png` `2.png` `3.png` `4.png` `5.png` `6.png` `7.png` `8.png` `9.png` `colon_top.png` `colon_bot.png`

### Row 7 — block-style "STARTCLEAR123"
`block_S.png` `block_T.png` `block_A.png` `block_R.png` `block_T_2.png` `block_C.png` `block_L.png` `block_E.png` `block_A_2.png` `block_R_2.png` `block_1.png` `block_2.png` `block_3.png`

### Row 8 — Nintendo + digit row
Original split merged the entire row into one blob (letters touched each other and the row above). Re-extracted in two passes:
- "Nintendo" letters: cut the y=55↔y=56 connection bridge to the digit row, then re-ran `img_split` with `--connectivity 4`.
- Digit row "0123456789E": grid-cut at 8-px intervals (the chars are uniform 8-col cells with no gap between them).

#### "Nintendo"
| File | Char | Notes |
|------|------|-------|
| `nin_N.png` | N | capital |
| `nin_i_dot.png` | · | dot of `i` |
| `nin_i.png` | i | body (lowercase) |
| `nin_lc_n.png` | n | first lowercase n (`lc_` prefix to avoid Windows case-clash with `nin_N`) |
| `nin_t.png` | t | |
| `nin_e.png` | e | |
| `nin_lc_n_2.png` | n | second lowercase n |
| `nin_d.png` | d | |
| `nin_o.png` | o | |

Bottom rows of these glyphs may be missing 1 px because the y=55 cut sliced through Nintendo's bottom row to break the digit-row connection. Visually negligible.

#### Digit row "0123456789E"
| File | Char |
|------|------|
| `row8_0.png` | 0 |
| `row8_1.png` | 1 |
| `row8_2.png` | 2 |
| `row8_3.png` | 3 |
| `row8_4.png` | 4 |
| `row8_5.png` | 5 |
| `row8_6.png` | 6 |
| `row8_7.png` | 7 |
| `row8_8.png` | 8 |
| `row8_9.png` | 9 |
| `row8_E.png` | E |

Each cell is exactly 8×8 px (the underlying digits touch each other column-wise — there's no transparent gutter).

## Rebuild from scratch

```
py _tools/img_split.py assets/low_pixels_Text.png --bg "#000001,#B57A57" --tolerance 4 -o assets/low_pixels_Text
```
