# Dragon Warrior (NES, USA) — RAM Reference

For the FlawlessNes challenge harness (BizHawk 2.11 / NesHawk).

## ROM identification

| Variant | iNES file SHA1 | Notes |
|---|---|---|
| PRG0 (original USA release, 1989) | `6A50CE57097332393E0E8751924FD56456EF083C` | Most common dump. |
| PRG1 / Rev A | `1ECC63AAAC50A9612EAA8B69143858C3E48DD0AE` | Minor revision. Same RAM map applies. |

Both are MMC1, 64K PRG / 16K CHR. Challenges should accept both hashes.

Sources: [TASVideos game versions](https://tasvideos.org/Games/67/Versions), [No-Intro / GameHacking.org Rev 1](https://gamehacking.org/game/29458).

## Player block (zero page)

| Address | Size | Name | Notes |
|---|---|---|---|
| `$00BA` | 2 LE | **Experience** | Unsigned 16-bit. Caps at 65535. **Lv 2 = 7 XP.** Curve: Lv3=23, Lv4=47, Lv5=110, Lv6=220, Lv7=450, … Lv30=65535. |
| `$00BC` | 2 LE | Gold | Unsigned 16-bit. |
| `$00C5` | 1 | **Current HP** | 0 = dead (transient — game teleports player to Tantegel after death sequence). |
| `$00C6` | 1 | Current MP | |
| `$00C7` | 1 | **Player Level** | Starts at 1. Watch `1 → 2` for level-up event. |
| `$00C8` | 1 | Strength | Recomputed; not source of truth. |
| `$00C9` | 1 | Agility | Recomputed. |
| `$00CA` | 1 | **Max HP** | |
| `$00CB` | 1 | Max MP | |
| `$00CC` | 1 | Attack Power | Derived from Str + weapon. |
| `$00CD` | 1 | Defense Power | Derived. |
| `$00BE` | 1 | Equipment | Packed (weapon high nibble, armor + shield low). |
| `$00BF` | 1 | Magic Keys | Count. |
| `$00C0` | 1 | Herbs | Count, max 9. |
| `$00C1`–`$00C4` | 4 | Inventory items | 8 slots, 2 per byte (low nibble = odd, high = even). |
| `$00CE` | 1 | Spells learned | bit0 Heal, bit1 Hurt, bit2 Sleep, bit3 Radiant, bit4 Stopspell, bit5 Outside, bit6 Return, bit7 Repel. |
| `$00CF` | 1 | Quest progress + extra spells | bit0 Healmore, bit1 Hurtmore, bit2 Secret stairs, bit3 Rainbow Bridge, bit4 Dragon's Scale, bit5 Fighter's Ring, bit6 Cursed Belt, bit7 Death Necklace. |

> **Caveat:** `$00C8`, `$00C9`, `$00CC`, `$00CD` are recomputed display values, not authoritative. For challenge logic key off `$00C7` (Level), `$00BA-BB` (XP), `$00C5`/`$00CA` (HP).

> **HP at level-up:** `$00C5` can briefly read above `$00CA` because HP is granted before MaxHP is updated. Clamp HP% renderings to 1.0 to avoid spikes.

## Position / map

| Address | Size | Name | Notes |
|---|---|---|---|
| `$003A` | 1 | Player X (current map, tile coords) | |
| `$003B` | 1 | Player Y (current map, tile coords) | |
| `$0045` | 1 | **Map ID** | `$01`=World, `$02`=Charlock, `$03`=Hauksness, `$04`=Tantegel Castle, `$05`=Throne Room, `$06`=Dragonlord's Lair, `$07`=Kol, `$08`=Brecconary, `$09`=Garinham, `$0A`=Cantlin, `$0B`=Rimuldar, `$0C`=Sun Shrine, `$0D`=Rain Shrine, `$0E`=Magic Temple, `$0F`–`$14`=Charlock B1–B6, `$15`=Swamp Cave, `$16`–`$17`=Mountain Cave B1–B2, `$18`–`$1B`=Garin's Grave B1–B4, `$1C`–`$1D`=Erdrick's Cave B1–B2. |
| `$0090`–`$0091` | 2 | Player X sprite-pixel | Higher precision than `$003A`. |
| `$0092`–`$0093` | 2 | Player Y sprite-pixel | |
| `$0094`–`$0095` | 2 | RNG state | `$95` is the live byte. |

> Tile coords lag sprite pixel coords by one frame during scrolling. For "left starting area" fail predicates use the map ID `$0045` (instant) over coordinate ranges.

## Battle / state detection

There is **no clean "in battle" boolean in WRAM**. Use the CHR-bank registers (System Bus, NOT WRAM domain):

| Address | Size | Name | Notes |
|---|---|---|---|
| `$6002` | 1 | CHR-ROM page 0 | `$00` = title screen, `$01` = everything else. |
| `$6003` | 1 | CHR-ROM page 1 | `$02` = non-battle, `$03` = **in battle**. Most reliable battle indicator. |
| `$00E0` | 1 | Terrain / enemy pointer (dual-use) | Out of battle: tile under player (grass=0, desert=1, hills=2, swamp=6, town=7, cave=8, etc.). In battle: enemy index. |
| `$00E2` | 1 | Enemy HP | **Not zeroed after battle** — don't use as "in battle" indicator. |
| `$00DF` | 1 | Combat / quest flags | bit0 princess rescued, bit1 returned, bit2 Death Necklace owned, bit3 left first room, bit4 player Stopspell'd, bit5 enemy Stopspell'd, bit6 enemy asleep, bit7 player asleep. Bits 4–7 cleared on combat entry. |

> No documented battle counter / encounter counter. Derive from `$6003` transitions `$02 → $03` if needed.

## Notes / gotchas

- All numeric values are unsigned binary (no BCD).
- XP wraparound theoretically possible at 65535 but no in-game mechanic causes it.
- Game is turn-based — the world only progresses on input. Challenges don't need a per-game freeze byte; the framework's `joypad.set({}, 1)` neutralization during banners is enough.
- Reading `$6002`/`$6003` in BizHawk requires the **System Bus** memory domain, not WRAM. If your harness uses `memory.read_u8` it should already use System Bus by default — verify.
- After death, HP at `$00C5` is 0 for several frames before the engine teleports the player to Tantegel and restores HP. Per-frame `fail()` polling at 60 fps reliably catches the death window.

## Items needing in-emulator verification

These would be useful but aren't in the public RAM maps:
- A clean "in dialogue / text-box open" boolean.
- A "shop menu open" boolean distinct from the battle-menu pointers `$00D8`/`$00D9`.
- A monotonic kill / encounter counter.

Don't ship guesses for these — verify in the BizHawk RAM Watch first.

## Sources

- [Data Crystal — Dragon Warrior/RAM map](https://datacrystal.tcrf.net/wiki/Dragon_Warrior/RAM_map) (primary)
- [ROM Detectives — Dragon Warrior (NES) RAM](http://www.romdetectives.com/Wiki/index.php?title=Dragon_Warrior_(NES)_-_RAM) (independent confirmation)
- [Dragons Den — DW1 NES experience table](https://www.woodus.com/den/games/dw1nes/exp_levels.php)
- [GamerCorner — DW NES levels](https://guides.gamercorner.net/dw/levels/)
