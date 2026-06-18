# Karnov (NES) — RAM reference

Working reference for authoring RetroChallenges challenges on Karnov (Data East / Sakata SAS, 1987 JP / 1988 US). A run-and-gun platformer across 9 stages where Jinborov "Karnov" Karnovski throws fireballs and collects equipment (ladders, boots, wings, bombs, shield, fireball upgrades) toward a final dragon fight.

**Sources:**
- [Data Crystal RAM map — Karnov](https://datacrystal.tcrf.net/wiki/Karnov/RAM_map) — primary reference for the addresses below.
- [Data Crystal game page — Karnov](https://datacrystal.tcrf.net/wiki/Karnov) — mapper / cart details.
- ROM hashes cross-checked against the [libretro NES DAT](https://github.com/libretro/libretro-database/blob/master/dat/Nintendo%20-%20Nintendo%20Entertainment%20System.dat) (No-Intro–derived, headered).

The public Karnov RAM map is **thin** compared to SMB/Castlevania — it covers game mode, player position/health/equipment, items, shots, and enemy/boss structures, but **does not document score, the in-game stage timer, displayed lives digits, or the bonus-letter pickups**. Those are flagged under [Open questions](#open-questions--to-verify) and need to be found by RAM-watching before any challenge relies on them.

## ROM hash verification

The framework pins a challenge to a ROM via `expected_rom_hashes`. BizHawk reports the **SHA1 of the iNES file (header included)** via `gameinfo.getromhash()` — that's the **headered** hash below. The launcher's rom-db also matches the **headerless** (No-Intro canonical) SHA1; both are supported (`src/rom-db.js`).

| Region | ROM filename | Headered SHA1 (iNES file — pin this) | CRC32 | MD5 |
|---|---|---|---|---|
| **USA** | `Karnov (USA).nes` | `CE5DA31FF7E5783D4E64B8CA015602778C22C49B` | `18EB6072` | `A7E40B7EF13BB9DAE972C3558043F1C9` |
| Japan (Rev 1) | `Karnov (Japan) (Rev 1).nes` | `932AAC8C6878C8E7B20142E2274E22583DF5A483` | `6B037BFD` | `95406DE452D59A879D2074341FB408A4` |
| Japan | `Karnov (Japan).nes` | `05F1957CE55766B637BFFDC352BABD476E988C6E` | `6A1F1561` | `0DE066C2D8E6EE80CB66DB404E03E06C` |

All three are 196624 bytes (16-byte iNES header + 128 KB PRG + 64 KB CHR). **Default to the USA dump** unless a challenge specifically targets the JP version.

> **Headerless (No-Intro) SHA1 not yet recorded** — it can't be computed without the ROM in hand. To get it, drop `Karnov (USA).nes` into the launcher's ROM folder and use **Scan ROMs**; `hashFile()` reports both `headered` and `headerless`. Add the headerless value here (and to `assets/nes-rom-db.json`) once verified.

Mapper 206 (Namco 118 / MIMIC-1), 128 KB PRG-ROM, 64 KB CHR-ROM, horizontal mirroring, no SRAM.

---

## Game state

| Address | What | Notes |
|---|---|---|
| `$0004` | Game-mode function pointer (2 bytes) | Engine's current state handler. |
| `$0010` | **Game mode** | `0x0B` = active play, `0x10` = final-boss fadeout, `0x11` = congratulations music begins (ending). Most useful: `read_u8(0x0010) == 0x0B` = "actually playing right now". |
| `$00C4` | Scrolling state | — |

> **For challenges**: gate `is_active = (read_u8(0x0010) == 0x0B)` to ignore title/transition/ending states.

---

## Display / scroll

| Address | What | Notes |
|---|---|---|
| `$000C` | Render scroll X | — |
| `$000D` | Render scroll Y | — |
| `$000E` | Render scroll Y high bit | `<< 4` (`$10` or `$00`). |
| `$0024` | Render palette (32 bytes) | — |
| `$0092` | Map scroll target X | — |
| `$0093` | Map scroll target Y | — |
| `$009F` | Map scroll X | Current camera X within the stage. |
| `$00A0` | Map scroll Y | Current camera Y within the stage. |
| `$00CA` | PPU update buffer (14 bytes) | — |

---

## Player state

| Address | What | Notes |
|---|---|---|
| `$0061` | **Current stage** | `0`–`8` (9 stages). Stage 8 is the final dragon. `read_u8(0x0061)` for "which stage". |
| `$0062` | **Player state** | Bit 7 = facing left. Other bits = motion/animation flags (verify before using). |
| `$0063` | **Player X position** | On-screen / map-relative X. |
| `$0064` | **Player Y position** | Higher value = lower on screen; watch for pit deaths. |
| `$0065` | **Player equipment** | Bit 4 = shield active; bits 3–0 = shot type / fireball power level (0 = base, higher = upgraded/multi-shot). |
| `$0068` | **Player health** | `0x00` = red/healthy, `0xC0` = blue (powered/extra hit), `0x80` = dead. Karnov is one-hit-ish; this byte is the life-state gate, not a multi-pip health bar. |

### Position notes
Karnov has no separate "screen vs level" X split documented — `$0063` is the working player X, `$009F` is the camera. Combine if you need absolute progress within a stage.

---

## Items & weapons

| Address | What | Notes |
|---|---|---|
| `$006E`–`$0070` | Shot status / X / Y (9 shots × 3 bytes) | Active fireballs. `$006E` block = status, then X, then Y arrays. |
| `$008F` | **Items bitfield** | Bit 5 = mask (reveals hidden / ghost), bit 1 = bombs held, bit 0 = boots (higher jump). |
| `$00BB` | **Bombs count** | Number of bombs currently held. |
| `$00C0`–`$00C2` | Bomb visibility / X / Y | A thrown/placed bomb's render + position. |
| `$00D8`–`$00DA` | Fireball-orb state / X / Y | The orbiting fireball "ball" power-up. |

> Karnov's shot upgrade ladder (single → multi-directional fireball) lives in `$0065` bits 3–0 per Data Crystal. The discrete "2-way / 3-way" mapping isn't spelled out in the public map — verify by collecting the **K** power-up and watching `$0065`.

---

## Map / collision / OAM

| Address | What | Notes |
|---|---|---|
| `$0200` | OAM buffer (256 bytes) | Sprite shadow OAM (DMA'd to PPU each frame). |
| `$040C` | 16 × 12 map tile-type buffer | Current screen's tile grid — collision, spawn triggers, pickups. |
| `$04CC` | Attribute cache | PPU attribute (palette) cache. |
| `$054C` | Row list for level background (13 bytes) | Background row layout data. |

---

## Enemies & bosses

Enemies live in a **6-slot table, 16-byte stride** starting at `$0650`. Fields below are offsets within each slot (slot N base = `0x0650 + N*0x10`):

| Offset / Address | What | Notes |
|---|---|---|
| `$0650` (+0) | Enemy type / active | Bits 6–0 = type; bit 7 = active (slot in use). |
| `$0651` (+1) | Enemy status | Bit 7 = facing left; bit 6 = falling from jump; bits 5–0 = state. |
| `$0652` (+2) | Enemy X | — |
| `$0653` (+3) | Enemy Y | — |
| `$0655` (+5) | Enemy damage | Hits taken / HP counter for that enemy. |

Boss / final-fight structures (these addresses are reused — "Dragon" labels apply to the stage dragon, "Boss" labels to the final boss):

| Address | What | Notes |
|---|---|---|
| `$06CF` | Dragon state / Boss head state | Bit 7 = active. |
| `$06D0` | Dragon damage / Boss sequence | Boss sequence runs 0–7. |
| `$06D2` | Boss damage (3 bytes) | Final boss only. |
| `$06DA` | Boss head X | — |
| `$06DB` | Dragon X / Boss head Y | — |
| `$06DC` | Dragon Y | — |
| `$06DD` | Dragon X high byte | — |
| `$06DE` | Dragon Y high byte | — |
| `$0706` | Boss fireball state | Bit 7 = active (final boss). |
| `$0707` | Boss fireball X | Final boss. |
| `$0708` | Boss fireball Y | Final boss. |
| `$040B` | **Lives count** | Remaining lives (internal counter — confirm whether it's display value or display-minus-one before using as a fail trigger). |

---

## Useful predicates

> **Lua API note.** Challenge scripts alias `local read_u8 = memory.read_u8 or memory.readbyte` (see any existing challenge). Addresses below are raw RAM addresses; BizHawk's `memory.read_u8` reads the NES system bus, where RAM is mirrored at `$0000–$07FF`, so these `< $0800` addresses read directly. **Bitwise tests must use the `bit` library (`bit.band`, `bit.bor`, `bit.lshift`) — the embedded Lua does not support the `&` operator.** `~=` (not-equal) is fine.

| What to detect | How |
|---|---|
| Active gameplay (not title/transition/ending) | `read_u8(0x0010) == 0x0B` |
| Reached stage N (0-indexed) | `read_u8(0x0061) == N` |
| Cleared the game (reached ending) | `read_u8(0x0010) == 0x10` (boss fadeout) → `0x11` (congrats) |
| Player died | `read_u8(0x0068) == 0x80`; or watch `$040B` (lives) decrement |
| Lost a life this frame (fail predicate) | Track previous `$040B`; fail when it decrements |
| Has shield up | `bit.band(read_u8(0x0065), 0x10) ~= 0` |
| Has boots | `bit.band(read_u8(0x008F), 0x01) ~= 0` |
| Has bombs (item flag) | `bit.band(read_u8(0x008F), 0x02) ~= 0` |
| Has mask | `bit.band(read_u8(0x008F), 0x20) ~= 0` |
| Holding ≥ N bombs | `read_u8(0x00BB) >= N` |
| No-upgrade run (base fireball only) | `bit.band(read_u8(0x0065), 0x0F) == 0` throughout |

> Verify `$040B` semantics (display value vs display−1, and what it reads on the last life) before shipping a lives-based fail predicate — Data Crystal labels it "Lives Count" without clarifying the off-by-one.

---

## Open questions / to verify

- **Score address** — not in the public RAM map. Find by watching RAM during fireball kills / item pickups before authoring any score challenge.
- **Stage timer** — Karnov's stages are untimed in the classic sense; confirm whether any countdown/clock byte exists. If not, all timing must come from the framework's own frame counter (`completionTime`).
- **Bonus letters / K-A-R-N-O-V** — the lettered power-ups (and the "spell KARNOV" bonus) aren't mapped. Verify which byte tracks collected letters if a challenge needs them.
- **`$0065` shot-power encoding** — confirm the exact bits-3–0 → fireball-spread mapping (single / double / triple / fan) empirically.
- **`$0068` health states** — `0xC0` "blue" appears to be the powered/extra-hit state; confirm it absorbs one hit and reverts to `0x00` rather than being a separate life.
- **`$040B` lives off-by-one** — see note above.

---

## Suggested first challenges

| Challenge | Win predicate | Fail predicate |
|---|---|---|
| **Clear Stage 1 fastest** | `$0061` rolls 0 → 1 | `$040B` decremented (death) |
| **Reach the dragon (Stage 9)** | `read_u8(0x0061) == 8` | Out of lives |
| **Beat the game** | `read_u8(0x0010) == 0x11` (ending) | Out of lives |
| **No-upgrade Stage 1** | `$0061` reaches 1 | `bit.band(read_u8(0x0065), 0x0F) > 0` at any point (picked up a fireball upgrade) |
| **Pacifist-ish / survival** | Survive N seconds in Stage 1 | `$0068 == 0x80` (died) |
| **Shieldless clear** | Stage cleared | `bit.band(read_u8(0x0065), 0x10) ~= 0` (shield ever active) |

---

*RAM addresses compiled from the datacrystal community map; ROM hashes from the libretro/No-Intro database. Several gameplay values (score, timer, bonus letters) are not yet in the public map and are flagged above — confirm by RAM-watching in BizHawk before relying on them.*
