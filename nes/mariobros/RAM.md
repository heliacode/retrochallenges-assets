# Mario Bros. (NES, 1983) — RAM reference

Working reference for the **1983 NES port of the arcade Mario Bros.** (not Super Mario Bros.). Single-screen, infinite phases, POW block, freezies, shellcreepers, sidesteppers. Two-player co-op.

**Sources:**
- [Data Crystal RAM map — Mario Bros.](https://datacrystal.tcrf.net/wiki/Mario_Bros./RAM_map) — primary reference.

This game is less reverse-engineered than SMB — Data Crystal documents the core scoring/lives/state but the per-enemy and entity-array specifics are sparse. Use BizHawk's RAM Watch when authoring anything beyond basic score/lives/phase challenges.

## ROM hash verification

| Region | ROM filename | SHA1 (iNES file) |
|---|---|---|
| (this dump) | `Mario Bros..nes` | `A684D6F5E0FA39B603038F041EE6E853203B44AD` |

> The file we have is 41,104 bytes — 128 bytes longer than the canonical iNES dump (40,976). Likely an over-dump with a trailing footer added by some ROM manager. The body is canonical Mario Bros. but the iNES SHA1 differs from the standard No-Intro entries. **For now, gate challenges on this exact SHA1**; if we later capture a clean canonical dump we'll add it to the whitelist alongside.

Cart code: NES-MA. Mapper 0 (NROM), 16 KB PRG, 8 KB CHR.

---

## Game state

| Address | What | Notes |
|---|---|---|
| `$0029` | **Game mode** | `0` = 1P A (single-player, normal), `1` = 1P B (single-player, hard), `2` = 2P A, `3` = 2P B. |
| `$003A` | Game A / B flag | `0` = A (easier ruleset), `1` = B (harder). |
| `$0041` | **Current displayed level** (phase number) | Phase 1, 2, 3, ... |
| `$002A` | Fine-timer | Frame-level timer. |
| `$002B` | Fine-timer (unpaused) | Pause-aware variant. |
| `$002D` | General coarse-timer | Higher-order timing. |
| `$002E` | Coarse-timer until next enemy spawn | — |
| `$0070` | **POW hits remaining** | The POW block degrades with each hit. `3` = fresh, `0` = used up. |
| `$0071` | Screen shake timer | Nonzero during a POW hit. |

---

## Players

| Address | What | Notes |
|---|---|---|
| `$0048` | **Player 1 lives** | Decrements on death. Game over when this rolls under 0 on the next death attempt. |
| `$004C` | Player 2 lives | 2P mode only. |
| `$0095-$0097` | **Player 1 score** | 3-byte BCD (the score shown in the top HUD). High byte first. |
| `$0099-$009B` | Player 2 score | 3-byte BCD. |
| `$0091-$0093` | High score | 3-byte BCD. |

> **Score reading helper (Lua)**:
> ```lua
> local function read_p1_score()
>   local hi  = read_u8(0x0095)
>   local mid = read_u8(0x0096)
>   local lo  = read_u8(0x0097)
>   -- BCD: each byte holds two decimal digits.
>   local function bcd(b) return math.floor(b / 16) * 10 + (b % 16) end
>   return bcd(hi) * 10000 + bcd(mid) * 100 + bcd(lo)
> end
> ```
> (The Mario Bros. arcade score is always a multiple of 10 — single coin/enemy = 800, ice flip = 100/200 — so the lowest BCD digit is effectively always zero. Confirm by RAM-watching during play.)

---

## Bonus stage

Every few phases, the game cuts to a coin-grab bonus round.

| Address | What | Notes |
|---|---|---|
| `$04B0` | Bonus game state | `0x00` = not in a bonus phase, `0x01` = bonus starting, `0x02` = active bonus phase. |
| `$04B1` | Bonus timer (seconds) | — |
| `$04B2` | Bonus timer (deciseconds) | — |
| `$04B3` | Bonus timer (frames) | — |
| `$04B5` | Bonus coins collected — P1 | Resets each bonus stage. |
| `$04B6` | Bonus coins collected — P2 | — |

---

## Entities

| Address range | What |
|---|---|
| `$0300-$031F` | **Mario** entity record (32 bytes) |
| `$0320-$033F` | **Luigi** entity record (32 bytes) |
| `$0340-$047F` | Enemy entity records (each 32 bytes; up to ~10 enemies) |
| `$0200-$02FF` | OAM page (sprite DMA buffer) |

The entity record layout (per-slot byte meanings — type, x, y, state, timer, etc.) **isn't documented on Data Crystal** for this game. To author position-based challenges:

1. Open BizHawk → Tools → RAM Watch.
2. Add `$0300`–`$031F` as 32 individual bytes.
3. Move Mario around the screen and observe which bytes change. X is typically a single byte; Y might be split (high/low pixel). State/animation will visibly flip during jumping/turning.
4. Save the discovered offsets back into this doc.

---

## Input

| Address | What |
|---|---|
| `$0018` | Controller 1 held buttons |
| `$0019` | Controller 1 held buttons (jump tapped only) |

(Standard NES flag pattern: bit 0=A, 1=B, 2=Select, 3=Start, 4=Up, 5=Down, 6=Left, 7=Right.)

---

## Useful predicates

| What to detect | How |
|---|---|
| Currently in a phase (not bonus) | `read_u8(0x04B0) == 0x00` |
| Currently in a bonus phase | `read_u8(0x04B0) == 0x02` |
| P1 lost a life this frame | Track previous `$0048`; fire when decremented. |
| Reached phase N | `read_u8(0x0041) >= N` |
| POW block already used | `read_u8(0x0070) == 0` |
| Score reached X | helper above + threshold compare |

---

## Open questions / to verify

- **Phase-cleared detection.** Data Crystal doesn't document a "phase complete" flag. Best signal is probably `$0041` incrementing — track previous value frame-to-frame.
- **Entity layout.** Need RAM-watch session (see Entities section).
- **Pause state.** No documented pause register. Use `$002A` (fine-timer) — if it stops advancing for >5 frames, the game is paused. (Untested — verify.)
- **Death detection.** Likely a per-entity state byte in `$0300-$031F`. Until mapped, fall back to watching `$0048` for the lives-decrement edge.

---

## Suggested first challenges

| Challenge | Win predicate | Fail predicate |
|---|---|---|
| **Reach Phase 5** | `$0041 >= 5` | `$0048` decremented (lost a life) |
| **Reach Phase 10** | `$0041 >= 10` | `$0048` decremented |
| **Score 50,000 in one life** | P1 score helper ≥ 50000 | `$0048` decremented |
| **Survive 2 minutes in 1P A** | Real-time `>= 120s` since challenge start | `$0048` decremented |
| **Phase 1 — no POW** | Phase advances to 2 | `$0070 < 3` (POW touched) |
| **Bonus stage — all 10 coins** | `$04B5 >= 10` during `$04B0 == 0x02` | bonus state changes back to 0 with < 10 |
