# font_1 — character map

Source: `font_1.png` → split into `font_1/` via `_tools/img_split.py`. Reference contact sheet: `font_1_sheet.png`.

## Naming conventions

- **Plain letters / digits**: `A.png` … `Z.png`, `0.png` … `9.png`.
- **Accented variants**: `<letter>_<accent>.png`
  - `_acute` (Á), `_grave` (À), `_circ` (Â), `_uml` (Ä), `_tilde` (Ñ).
- **Punctuation** (Windows-safe ASCII names):
  - `!` → `excl_*`
  - `?` → `qmark`, `¿` → `iqmark`
  - `/` → `slash`
  - `.` → `period`, `,` → `comma`
  - `-` → `dash*`
  - `×` → `times`
- **Loose accent marks** (diacritics that did not merge with their letter): `mark_acute`, `mark_grave`, `mark_dot_*`.
- **Merged tokens** (full words kerned tightly enough that 8-connectivity merged them): `DEL.png`, `OK.png`, `SPC.png`.
- **Duplicates** (same glyph appearing more than once in the source — usually because letters from the `GLOVER!!!Ü` example string and the alphabet row both got captured): suffix `_2`, `_3`.
- **`example_` prefix**: small dark text labels from the source's literal `example:` annotation, not part of the playable font.

## Files

### Letters
| File | Char | Notes |
|------|------|-------|
| `A.png` | A | |
| `A_acute.png` | Á | |
| `A_acute_2.png` | Á | second acute-A on source sheet |
| `A_circ.png` | Â | |
| `A_uml.png` | Ä | |
| `B.png` | B | |
| `C.png` | C | |
| `D.png` | D | |
| `E.png` | E | |
| `E_2.png` | E | dup (from "GLOVER") |
| `E_acute.png` | É | |
| `E_grave.png` | È | |
| `E_grave_2.png` | È | second grave-E on source sheet |
| `F.png` | F | |
| `G.png` | G | |
| `G_2.png` | G | dup (from "GLOVER") |
| `H.png` | H | |
| `I.png` | I | |
| `I_acute.png` | Í | |
| `I_grave.png` | Ì | |
| `J.png` | J | |
| `K.png` | K | |
| `L.png` | L | |
| `L_2.png` | L | dup (from "GLOVER") |
| `M.png` | M | |
| `N.png` | N | |
| `N_tilde.png` | Ñ | |
| `O.png` | O | |
| `O_2.png` | O | dup (from "GLOVER") |
| `O_acute.png` | Ó | |
| `O_grave.png` | Ò | |
| `O_uml.png` | Ö | |
| `P.png` | P | |
| `Q.png` | Q | |
| `R.png` | R | |
| `R_2.png` | R | dup (from "GLOVER") |
| `S.png` | S | |
| `T.png` | T | |
| `U.png` | U | |
| `U_2.png` | U | dup |
| `U_3.png` | U | dup |
| `U_acute.png` | Ú | |
| `V.png` | V | |
| `V_2.png` | V | dup (from "GLOVER") |
| `W.png` | W | |
| `X.png` | X | |
| `Y.png` | Y | |
| `Z.png` | Z | |

### Digits
| File | Char |
|------|------|
| `1.png` | 1 |
| `2.png` | 2 |
| `3.png` | 3 |
| `4.png` | 4 |
| `5.png` | 5 |
| `6.png` | 6 |
| `7.png` | 7 |
| `8.png` | 8 |
| `9.png` | 9 |

### Punctuation
| File | Char | Notes |
|------|------|-------|
| `comma.png` | , | |
| `dash.png` | - | |
| `dash_2.png` | - | dup |
| `dash_3.png` | - | dup |
| `dash_4.png` | - | dup |
| `excl_2.png` | ! | from "GLOVER!!!" |
| `excl_3.png` | ! | from "GLOVER!!!" |
| `excl_4.png` | ! | from "GLOVER!!!" |
| `iqmark.png` | ¿ | |
| `qmark.png` | ? | |
| `slash.png` | / | |
| `times.png` | × | |

### Merged tokens
| File | Notes |
|------|-------|
| `DEL.png` | "DEL" button label, captured as one component |
| `OK.png` | "OK" button label |
| `SPC.png` | "SPC" (space) button label |

### Loose diacritic marks
| File | Notes |
|------|-------|
| `mark_acute.png` | floating ´ |
| `mark_grave.png` | floating ` |
| `mark_dot_1.png` … `mark_dot_15.png` | small dot/diaeresis fragments that didn't merge with their letter bodies |

### `example:` label fragments (not really font glyphs)
| File | Char |
|------|------|
| `example_a.png` | a |
| `example_colon.png` | : |
| `example_e.png` | e |
| `example_e_2.png` | e |
| `example_l.png` | l |
| `example_m.png` | m |
| `example_p.png` | p |
| `example_period.png` | . (or fragment) |
| `example_x.png` | x |

## Open items

- No canonical `excl.png` — the `!` from row 4 of the source was reclassified as `comma.png` during review, leaving only the three `excl_*` sprites from `GLOVER!!!` (all the same glyph). If you need a canonical `!`, promote one of them: `mv excl_2.png excl.png`.
- `mark_dot_*` are largely interchangeable; consolidate or discard as needed.
- `example_*` files are descriptive label text from the source image, not playable font sprites — likely safe to delete if you only want the font itself.

## Rebuild from scratch

```
py _tools/img_split.py assets/font_1.png -o assets/font_1
```
