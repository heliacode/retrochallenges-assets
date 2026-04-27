# Mega Man 2 (NES) — RAM reference

Working reference for authoring RetroChallenges challenges on Mega Man 2 (US/JP NES, mapper 1). Most entries are transcribed from the [Data Crystal RAM map](https://datacrystal.tcrf.net/wiki/Mega_Man_2:RAM_map); a handful at the bottom are **unverified** and need confirmation via BizHawk's RAM Watch / RAM Search before being baked into a challenge script.

---

## Player

### Health, lives, energy tanks

| Address | Bytes | What | Notes |
|---|---|---|---|
| `$06C0` | 1 | Mega Man HP | Full = `0x1C` (28). Damage subtracts. |
| `$00A8` | 1 | Lives remaining | Display glitches if `> 0x64`. |
| `$00A7` | 1 | E-Tanks held | Can store > `4` but breaks the password screen. |
| `$004B` | 1 | I-frames timer | Counts down 1/frame. `> 0` = invincible. |
| `$00CB` | 1 | Difficulty | `0x00` = Normal (US "Difficult"), `0x01` = Easy (US "Normal"). Damage is bit-shifted left when `0`. |

### Position / motion

| Address | Bytes | What | Notes |
|---|---|---|---|
| `$0460` | 1 | Mega Man X position | Within current screen. |
| `$04A0` | 1 | Mega Man Y position | Within current screen. |
| `$0F15` | 1 | Mega Man X coord | Alternate / display copy. |
| `$0F16` | 1 | Mega Man Y coord | Alternate / display copy. |
| `$0F12` | 1 | Facing direction | `0x00` = left, `0x01` = right. |
| `$0036` | 1 | Shooting-pose timer | — |
| `$003D` | 1 | Is shooting? | — |

### Tile under Mega Man

| Address | Bytes | What | Value mapping |
|---|---|---|---|
| `$0032` | 1 | Tile at feet | `0x00` air, `0x01` ground, `0x02` ladder, `0x03` instakill, `0x04` water, `0x05` right conveyor, `0x06` left conveyor, `0x07` ice |
| `$0033` | 1 | Tile at center | Same mapping as `$0032`. |
| `$0034` | 1 | Tile overlapping | Same mapping as `$0032`. |

> **`$0032 == 0x03`** is the cleanest "Mega Man just touched a death tile" signal — useful as a fail predicate for pit / spike challenges.

---

## Weapons & items

### Unlocked-weapon bitfield — `$009A`

Each bit set = that weapon has been picked up. The byte stores all 8 flags at once.

| Bit | Hex | Weapon |
|---|---|---|
| 0 | `0x01` | **Atomic Fire** (Heat Man — H) |
| 1 | `0x02` | **Air Shooter** (Air Man — A) |
| 2 | `0x04` | **Leaf Shield** (Wood Man — W) |
| 3 | `0x08` | **Bubble Lead** (Bubble Man — B) |
| 4 | `0x10` | **Quick Boomerang** (Quick Man — Q) |
| 5 | `0x20` | **Time Stopper** (Flash Man — F) |
| 6 | `0x40` | **Metal Blade** (Metal Man — M) |
| 7 | `0x80` | **Crash Bomber** (Crash Man — C) |

Set this to `0xFF` to unlock everything for a challenge.

### Per-weapon ammo

Each weapon has its own ammo byte. Full ammo is `0x1C` (28) — same scale as Mega Man's HP.

| Address | Weapon | Notes |
|---|---|---|
| `$009C` | Atomic Fire | Charge weapon — high cost per shot. |
| `$009D` | Air Shooter | |
| `$009E` | Leaf Shield | Ammo decrements when the shield is fired off, not when summoned. |
| `$009F` | Bubble Lead | |
| `$00A0` | Quick Boomerang | |
| `$00A1` | Time Stopper | Drains while active. |
| `$00A2` | Metal Blade | |
| `$00A3` | Crash Bomber | |

### Items (utility platforms)

| Address | Bit | Item |
|---|---|---|
| `$009B` | `0x01` | Item-1 (Helicopter Platform) — vertical |
| `$009B` | `0x02` | Item-2 (Jet Sled) — horizontal |
| `$009B` | `0x04` | Item-3 (Climbing Platform) — wall-climber |

| Address | Item ammo |
|---|---|
| `$00A4` | Item-1 ammo |
| `$00A5` | Item-2 ammo |
| `$00A6` | Item-3 ammo |

> **Currently equipped weapon byte: NOT YET CONFIRMED.** Data Crystal lists only the unlocked-weapon flags at `$009A`, not the *selected* weapon. There must be a separate byte (the pause menu cycles between equipped weapons). Likely in the `$00` page near the weapon group. **TODO:** scan with RAM Search by toggling the weapon select on the pause menu.

---

## Bosses & enemies

| Address | What | Notes |
|---|---|---|
| `$06C1` | Boss HP | All 8 Robot Masters + Wily-stage bosses share this slot. Full HP usually `0x1C` (28). Win condition: `read_u8(0x06C1) == 0`. |
| `$06C2` – `$06E1` | Enemy HPs | 32 enemy slots. |

---

## Stage select / level state

| Address | What | Notes |
|---|---|---|
| `$002A` | Stage-select cursor position | `0x00` = Dr. Wily, `0x01–0x08` = clockwise from Bubble Man on the select screen (see mapping below). |

### Stage-select cursor mapping (`$002A`)

The Robot Masters arrange clockwise on the select screen, starting from the **Bubble Man** slot at top-left (which is `0x01`). To start a specific Robot Master stage from the select screen, write the cursor value here and simulate Start.

| Value | Stage |
|---|---|
| `0x00` | Dr. Wily (centre, post-RM) |
| `0x01` | **Bubble Man** |
| `0x02` | **Air Man** |
| `0x03` | **Quick Man** |
| `0x04` | **Wood Man** |
| `0x05` | **Crash Man** |
| `0x06` | **Flash Man** |
| `0x07` | **Metal Man** |
| `0x08` | **Heat Man** |

> Order verified from Data Crystal ("clockwise starting from Bubble Man"). The stage-select-to-actual-stage byte (the value the engine writes once you confirm) is **NOT YET CONFIRMED** — likely separate from `$002A`. **TODO:** RAM-watch when pressing Start on the select screen.

---

## Camera

| Address | What | Notes |
|---|---|---|
| `$001B` | Camera state | `0x00` default, `0x01` changing nametable, `0x02` freeze before/after scroll, `0x80` scrolling vertically. |
| `$001F` | Camera X position | Within screen. |
| `$0020` | Camera X screen | High byte — increments when `$001F` rolls over. |
| `$0022` | Camera Y position | — |

---

## Input (controller polling)

| Address | What | Notes |
|---|---|---|
| `$0023` | Controller 1 — current frame's poll | Bitmask: `A B Sel Sta Up Dn Lt Rt`. |
| `$0025` | Controller 1 — mirror | Same as above; persists across frames. |
| `$0027` | Controller 1 — first frame of state change | Crash Man's AI checks this for "is the player jumping right now". |

---

## Graphics / palette

| Address | What | Notes |
|---|---|---|
| `$0200`–`$02FF` | Sprite memory | Constantly DMA'd to OAM. Don't touch from a challenge. |
| `$0354` | Palette cycling pattern | Level-dependent. |
| `$0355` | Palette cycling speed | `0x00` = no cycling. |
| `$0356`–`$0365` | Background palette memory | — |
| `$0366`–`$0375` | Sprite palette memory | — |
| `$0367`–`$0369` | Mega Man's palette | Subset of the sprite palette. Useful for visual indicators (flash on hit, etc.). |
| `$0F39` | Gameplay frame counter | Pauses on the pause menu. Useful as a frame-accurate timer that respects player-paused time. |

---

## Sound

| Address | What | Notes |
|---|---|---|
| `$0066` | SFX strobe | Write `0x01` to play the SFX whose ID lives at `$0580`. |
| `$0067` | Music strobe | Write `0x01` to play music whose ID lives at `$0000`. |
| `$0580` | SFX queue | Holds the next SFX to play. |

---

## Password screen

| Address | What | Notes |
|---|---|---|
| `$0420`–`$0438` | Password dot grid | `0x01` = grid space contains a dot, `0x00` = empty. |
| `$0680` | Cursor / dots-remaining | Dual-purpose during password entry. |

---

## Open questions / things to confirm with RAM Watch

1. **Currently-equipped weapon byte.** Pause-menu cycle should toggle a single byte. Most likely in the `$00` page near `$009A`–`$00A8`. Test: open pause menu, cycle weapon, watch which byte changes.
2. **Stage-load byte.** Pressing Start on the select screen surely writes a "go to stage N" value somewhere. `$002A` is just the cursor.
3. **Game-state byte.** Title vs. password vs. stage-select vs. in-stage vs. boss-room vs. game-over. Need a single byte we can read to know "the player is in active gameplay" so the timer doesn't start until they're actually playing. Likely in the `$00` page; classic Mega Man games use addresses like `$0030` or `$01FE` for this kind of state.
4. **Boss-room transition flag.** Useful for "freeze the timer until the boss room loads" or "fail if the player exits the boss room". Probably part of the camera state at `$001B`.

Adding these will make the framework's `setup` / `win` / `fail` callbacks much more robust for Mega Man 2 challenges.

---

## ROM notes

- Cart code: NES-MW (US), CAP-MW-NES (JP). Mapper 1 (MMC1).
- US "Difficult" = JP "Normal"; US "Normal" = a damage-halved beginner mode unique to the US release.
- The `$00CB` difficulty byte controls this — challenges that depend on damage values should pin it to `0x00` in `setup` to standardize.

---

## Suggested first challenges to author against this map

| Challenge | Win | Fail | Stage-select trick |
|---|---|---|---|
| **Defeat any single Robot Master** | `read_u8(0x06C1) == 0` | `read_u8(0x06C0) == 0` (HP zero) | Player picks; framework just records `$002A` at win for telemetry |
| **Beat Metal Man** specifically | Same | Same | `setup` writes `$002A = 0x07` and simulates Start |
| **Beat the first Wily stage boss** | Same | Same | Needs a savestate post-RM-rush |
| **No-damage Heat Man** | Same | Mega Man HP < starting HP | `$002A = 0x08` |
| **Pit-run Quick Man's stage** (no shooting) | Reach Quick Man boss room | `$0032 == 0x03` (instadeath tile) | Honor system on the no-shooting rule, or detect via `$003D` |

Once the equipped-weapon byte is confirmed, "buster only" / "use only weapon X" challenges become enforceable too.
