# Metal Gear (NES) — RAM reference

Working reference for authoring RetroChallenges challenges on Metal Gear (Konami, 1987 NES port of the MSX2 original). Solid Snake infiltrates Outer Heaven, sneaks past guards, rescues hostages and Dr. Pettrovich Madnar, and destroys the Metal Gear supercomputer.

**Sources:**
- User-supplied RAM-Watch capture — primary source for everything below. Addresses observed live in BizHawk RAM-Watch, not yet cross-verified against a disassembly.
- [Data Crystal RAM map — Metal Gear (NES)](https://datacrystal.tcrf.net/wiki/Metal_Gear_(NES)/RAM_map) — community-curated; use as a cross-check when extending this map.

> ⚠ Treat every address here as **provisional**. They were found by watching RAM during play, not derived from a disassembly. When a challenge predicate behaves unexpectedly, put the raw byte on the HUD (don't guess) and confirm against Data Crystal.

## ROM hash verification

The framework can pin a challenge to a specific ROM via `expected_rom_hashes` in the challenge spec. BizHawk reports the **SHA1 of the iNES file (header included)** via `gameinfo.getromhash()` — the file-level hash, not the No-Intro / GoodNES headerless convention.

`RcChallenge` logs `[RC] ROM SHA1: <HEX>` to BizHawk's Lua console on every launch. Run any Metal Gear challenge once with your real ROM, copy the value, and paste it into both the challenge file's `expected_rom_hashes` array and this table:

| Region | ROM filename | SHA1 (iNES file) |
|---|---|---|
| USA | `Metal Gear (USA).nes` | _capture from your dump_ |

Cart code: NES-MG (US). Mapper 1 (MMC1).

---

## Snake (player)

| Address | What | Notes |
|---|---|---|
| `$0035` | **Snake X position** | Pixel X within the current room/screen. |
| `$0036` | **Snake Y position** | Pixel Y within the current room/screen. |
| `$006D` | **Snake HP** | Decrements on damage. `0` = dead — universal fail signal. Capture max in `setup` via RAM-Watch. |
| `$0025` | **Paused flag** | Nonzero while the game is paused. Candidate per-game pause byte for `freeze_game` / `release_game` — verify in RAM-Watch before relying on it; otherwise the framework's universal freeze (slot 9) covers the countdown. |

---

## Game / screen state

| Address | What | Notes |
|---|---|---|
| `$0030` | **Current area / room ID** | Identifies which room Snake is in. The core progress indicator — capture starting value in `setup` and compare. |
| `$0012` | Universal timer | Free-running frame-ish counter. Sanity check that the engine is still ticking. |
| `$001A` | Spawn timer | Counts during enemy/entity spawn sequencing. |
| `$0011` | Screen transition state | Nonzero while a room transition is in progress — gate predicates so they don't fire mid-transition. |
| `$006B` | Current menu / textbox state | Nonzero while a menu or textbox is open. Use to gate "is Snake actually playing" — and to pause a timer during codec/intro text. |
| `$0066` | Room counter | Counts rooms entered; rough progress metric. |
| `$07C9` | Maze zone | Identifies the current maze zone. |

---

## Bosses / events

| Address | What | Notes |
|---|---|---|
| `$0044` | **Boss 1 HP** | `0` = defeated. Win predicate for the first boss fight. |
| `$0055` | **Boss 2 HP** | `0` = defeated. Win predicate for the second boss fight. |
| `$0073` | **Pettrovich rescued flags** | Flag(s) tracking the Dr. Pettrovich Madnar rescue. Likely a bitfield — RAM-Watch the exact bit before pinning a predicate. |
| `$0071` | **Supercomputer beaten flag** | Set when the Metal Gear supercomputer is destroyed. The natural "game complete" win signal. |

---

## Snake bullets (6 slots)

Parallel arrays, one byte per slot, slots `0`–`5`.

| Address range | What |
|---|---|
| `$0302`–`$0307` | Bullet active flags (per slot — nonzero = bullet in flight) |
| `$0342`–`$0347` | Bullet X positions |
| `$0322`–`$0327` | Bullet Y positions |

```lua
-- iterate Snake's bullets
for i = 0, 5 do
    local active = read_u8(0x0302 + i)
    local bx     = read_u8(0x0342 + i)
    local by     = read_u8(0x0322 + i)
end
```

---

## Enemies (8 slots)

Parallel arrays, one byte per slot, slots `0`–`7`.

| Address range | What |
|---|---|
| `$0308`–`$030F` | Enemy active flags (per slot — nonzero = enemy present) |
| `$0348`–`$034F` | Enemy X positions |
| `$0328`–`$032F` | Enemy Y positions |
| `$00B8`–`$00BF` | Enemy timers (per-slot AI / animation timers) |

```lua
-- count active enemies
local count = 0
for i = 0, 7 do
    if read_u8(0x0308 + i) ~= 0 then count = count + 1 end
end
```

---

## Enemy bullets (8 slots)

Parallel arrays, one byte per slot, slots `0`–`7`.

| Address range | What |
|---|---|
| `$0310`–`$0317` | Enemy bullet active flags |
| `$0350`–`$0357` | Enemy bullet X positions |
| `$0330`–`$0337` | Enemy bullet Y positions |

---

## Useful predicates

| What to detect | How |
|---|---|
| Snake died | `read_u8(0x006D) == 0` — or edge-trigger HP dropping to 0 |
| Took any damage (no-damage challenges) | Track previous HP; fail when `read_u8(0x006D) < prev_hp` |
| Reached a specific room | `read_u8(0x0030) == TARGET_ROOM` |
| Left the starting room | `read_u8(0x0030) ~= start_room` (capture `start_room` in `setup`) |
| Defeated Boss 1 | `read_u8(0x0044) == 0` while in the boss room |
| Defeated Boss 2 | `read_u8(0x0055) == 0` while in the boss room |
| Destroyed Metal Gear | `read_u8(0x0071) ~= 0` |
| Rescued Pettrovich | `read_u8(0x0073) ~= 0` (confirm exact bit in RAM-Watch) |
| Pacifist constraint (no enemy killed) | Track enemy active flags; fail if a slot flips active → inactive while on-screen |
| Currently in a menu / textbox | `read_u8(0x006B) ~= 0` — gate the timer / predicates |
| Mid room-transition | `read_u8(0x0011) ~= 0` — don't evaluate win/fail this frame |

---

## Open questions / to verify

- **`$006D` max HP** — capture the value at full health in RAM-Watch; needed for no-damage and "heal to full" loadouts.
- **`$0025` pause semantics** — confirm it both reads `1` when paused and that *writing* it actually freezes the engine before using it as a per-game `freeze_game` byte.
- **`$0073` Pettrovich flags** — is it a bitfield (multiple rescue stages) or a single boolean? RAM-Watch through an actual rescue.
- **`$0030` vs `$0066` vs `$07C9`** — three room-ish bytes. Establish which is the stable per-room identifier vs. a running counter vs. a maze-local index by walking between known rooms.
- **Enemy "defeated" signal** — confirm whether a killed enemy clears its `$0308+i` flag immediately or after a death animation; affects pacifist / kill-count detection.

---

## Suggested first challenges

| Challenge | Win predicate | Fail predicate |
|---|---|---|
| **Escape the starting room** | `$0030 ~= start_room` | `$006D == 0` |
| **No-damage room run** | reach `TARGET_ROOM` | `$006D < start_hp` OR `$006D == 0` |
| **Defeat Boss 1** | `$0044 == 0` | `$006D == 0` |
| **Defeat Boss 2** | `$0055 == 0` | `$006D == 0` |
| **Rescue Dr. Pettrovich** | `$0073` rescue bit set | `$006D == 0` |
| **Destroy Metal Gear** | `$0071 ~= 0` | `$006D == 0` |
| **Pacifist room clear** | reach `TARGET_ROOM` | `$006D == 0` OR any enemy killed |
