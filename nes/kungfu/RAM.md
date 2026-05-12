# Kung Fu (NES) — RAM reference

Working reference for authoring RetroChallenges challenges on Kung Fu (Irem / Nintendo, 1985 NES port of "Kung-Fu Master"). Five floors of a temple — Thomas punches and kicks waves of enemies on each, ending with a boss fight, to rescue Sylvia from Mr. X.

**Sources:**
- [Data Crystal RAM map — Kung Fu](https://datacrystal.tcrf.net/wiki/Kung_Fu/RAM_map) — primary (and only public) source.

Kung Fu is much less reverse-engineered than e.g. SMB — Data Crystal documents 14 bytes covering the basics (stage, HP, lives, score) but no entity / enemy layout. Use BizHawk RAM-Watch to fill in gaps when authoring more elaborate challenges.

## ROM hash verification

The framework can pin a challenge to a specific ROM via `expected_rom_hashes` in the challenge spec. BizHawk reports the **SHA1 of the iNES file (header included)** via `gameinfo.getromhash()`.

| Region | ROM filename | SHA1 (iNES file) |
|---|---|---|
| (this dump) | `kungfu.nes` | `9DF403DAC695B556ADBBF312DF37E3B76A2191AC` |

> The file we have is 65,679 bytes with a 2 PRG / 4 CHR header — non-canonical for stock Kung Fu (USA), which is 40,976 bytes (2 PRG / 1 CHR). Probably an over-dump with extra/duplicated CHR data; the game still boots correctly on mapper-0. We gate on this exact SHA1 until / unless a clean dump replaces it, at which point we add the canonical hash alongside.

Cart code: NES-KF. Mapper 0 (NROM).

---

## Game state

| Address | What | Notes |
|---|---|---|
| `$0008` | Game submode | Function not documented upstream; probably an inner state machine. Verify via RAM-Watch. |
| `$0051` | **Game mode** | Function not documented in detail. Use as a "I am actually playing" gate after RAM-watch confirmation. |
| `$0058` | **Current stage** (floor) | Increments when Thomas clears the current floor and the game advances. 0-indexed or 1-indexed unverified — capture starting value in setup and compare. |
| `$0056` | Defeat count | Probably the number of enemies defeated on the current floor (or the run total). |
| `$0049` | Frame counter | Counts up every frame; mostly useful as a "is the engine still ticking" sanity check. |

---

## Thomas (player)

| Address | What | Notes |
|---|---|---|
| `$005C` | **Lives remaining** | Decrements on death. Universal death detector. |
| `$04A6` | **Hero HP / energy** | `$4D` (or possibly `$40` = 64) is max per Data Crystal — the source flags the discrepancy and asks for verification. RAM-Watch to confirm. `0` = dead, decrements via hit damage and timer-tick. |
| `$0021` | Hero action timer | Likely counts down during attack / damage animations — Thomas is invulnerable / locked while non-zero. |
| `$0378` | "Shrug off enemy" counter | Triggered when a grappler latches on; counts down as Thomas mashes free. |
| `$0391` | MSB time digit | The countdown clock's high digit. Must be free to decrement for the level to end — i.e. freezing this stops level-end transitions. |

---

## Enemy / boss

| Address | What | Notes |
|---|---|---|
| `$004E` | **Boss action** | Inner state of the current floor boss. Per-boss meanings unverified — capture in RAM-Watch during a boss fight to learn the values. |
| `$04AF` | **Enemy HP** | The "active" enemy's HP — most commonly the boss. `$FF` (255) is documented as "instant death". `0` = defeated. |
| `$002B-$002E` | Enemy 1-3 action timers | Side-scrolling enemy slots' attack / animation timers. (Data Crystal lists `$002E` as "Enemy 3" but the row before is also labelled "3"; treat the third as a typo for "Enemy 4" pending RAM-Watch.) |

---

## Score

| Address | What | Notes |
|---|---|---|
| `$0531-$0535` | **Score** | 5 bytes. Format unspecified upstream — likely BCD digits (one per byte, top-to-bottom). RAM-Watch to confirm; if BCD, read with `bcd_byte` per the SMB pattern. |

---

## Useful predicates

| What to detect | How |
|---|---|
| Cleared the current floor | `read_u8(0x0058) > start_stage` (capture start_stage in setup) |
| Defeated the current floor boss | `read_u8(0x04AF) == 0` while still on the same stage |
| Lost a life (death) | `read_u8(0x005C) < prev_lives` (edge-trigger, prev_lives captured in setup) |
| Thomas at full HP | `read_u8(0x04A6) >= 0x40` (or `0x4D` — see note above) |
| Took any damage (no-damage challenges) | Track previous HP; fail when current < previous. |

---

## Open questions / to verify

- **`$04A6` max value**: Data Crystal lists `$4D` (77) AND `$40` (64) as max with a comment "these values are not equal, please verify". Run any challenge once and RAM-watch what the bar maxes out at.
- **`$0058` indexing**: 0-indexed (Floor 1 = 0) or 1-indexed (Floor 1 = 1)? Capture in setup and compare relative.
- **`$0531-$0535` format**: BCD or binary, byte order? RAM-watch as Thomas gains points and check whether `$0531` is the high or low digit byte.
- **Enemy/entity per-slot data**: not documented. Author challenges that don't need this until we've RAM-walked it.

---

## Suggested first challenges

| Challenge | Win predicate | Fail predicate |
|---|---|---|
| **Complete Floor 1** | `$0058 > start_stage` | Lives decremented |
| **No-damage Floor 1** | `$0058 > start_stage` | `$04A6 < start_hp` OR lives decremented |
| **Beat Floor 1 boss** | `$04AF == 0` while still on floor 1 | Lives decremented |
| **Reach Floor 3** | `$0058 >= start_stage + 2` | Lives decremented |
| **Survive 1 minute on Floor 5** | real-time `>= 60s` | Lives decremented |
