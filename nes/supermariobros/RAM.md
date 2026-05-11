# Super Mario Bros. (NES) — RAM reference

Working reference for authoring RetroChallenges challenges on Super Mario Bros. (World, 1985, mapper 0 NROM-256). The World release is the dump everyone has; US-only and JP-only variants don't exist in retail — it's a single shared World ROM.

**Sources:**
- [Data Crystal RAM map — Super Mario Bros.](https://datacrystal.tcrf.net/wiki/Super_Mario_Bros./RAM_map) — primary reference for everything below.
- Cross-checked against `jdaster64/smbdis` disassembly where ambiguous.

All addresses below are verified against Data Crystal unless explicitly marked. SMB's RAM layout is one of the most-mapped on the NES.

## ROM hash verification

The framework can pin a challenge to a specific ROM via `expected_rom_hashes` in the challenge spec. BizHawk reports the **SHA1 of the iNES file (header included)** via `gameinfo.getromhash()` — this is the file-level hash, not the No-Intro / GoodNES headerless convention.

| Region | ROM filename | SHA1 (iNES file) |
|---|---|---|
| World | `Super Mario Bros. (World).nes` | `EA343F4E445A9050D4B4FBAC2C77D0693B1D0922` |

There's only one retail SMB dump — the same file shipped worldwide. The "USA" and "Japan" labels you sometimes see in dumps are just renames of this same file.

Cart code: NES-SM. Mapper 0 (NROM-256), 32 KB PRG, 8 KB CHR-ROM.

---

## Game state

| Address | What | Notes |
|---|---|---|
| `$0770` | **Game mode** | `0x00` = before title, `0x01` = title screen / demo, `0x02` = in-level gameplay, `0x03` = game over. Most useful: `read_u8(0x0770) == 0x02` = "Mario is actually playing right now". |
| `$0772` | Operation mode (level loading) | `0x00` restart level, `0x01` right before level start, `0x02` has area animation, `0x03` actively playing, `0x04` end-of-level animation. |
| `$0776` | Game pause status | Nonzero = paused. |
| `$0777` | Game pause timer | Re-pause cooldown — can only un/re-pause when this is 0. |
| `$07A0` | "Prelevel" screen timer | Counts down during the "WORLD X-Y" splash before the level proper starts. |
| `$07A2` | Demo start timer | If the title screen idles long enough this triggers the autoplay demo. |
| `$0747` | Timer control | — |
| `$07B1` | "Event music buffer" | If true, dying small / falling won't end the run (used during dying animations). |

> **For challenges**: gate `is_active = (read_u8(0x0770) == 0x02)` to ignore title/demo/pause/game-over states. Pair with `read_u8(0x0772) == 0x03` if you want to also exclude the level-start animation.

---

## Player state

| Address | What | Notes |
|---|---|---|
| `$0754` | **Player powerup state** | `0x00` = big (super), `0x01` = small, `0x02+` = fiery. Note: counter-intuitive — `0x00` is big, not small. |
| `$0756` | Powerup mirror | `0x00` = small, `0x01` = big, `0x02+` = fiery. **This is the one to use for "stay small" / "fire-flower only" rules** — matches HUD logic. |
| `$000E` | Player's animation state | `0x00` = leftmost of screen, `0x01` = climbing vine, `0x02` = entering reversed-L pipe, `0x03` = going down pipe, `0x04` = auto-walk (level start / castle end), `0x05` = death, `0x06` = end-of-level kicks, `0x07` = level entry. |
| `$001D` | Player float state | `0x00` standing, `0x01` airborne by jumping, `0x02` airborne by walking off ledge, `0x03` sliding down flagpole. |
| `$0033` | Player facing direction | `0` not on screen, `1` right, `2` left. |
| `$0045` | Player moving direction | `1` right, `2` left. |
| `$0704` | Swimming flag | Set to 1 when swimming (underwater levels). |
| `$0714` | Ducking flag | `0x04` when ducking as big Mario, `0x00` otherwise. |
| `$079E` | Invincibility timer (post-hit) | Counts down i-frames after taking damage. |
| `$079F` | Star invincibility timer | Counts down while you have a star powerup. |

### Position

| Address | What | Notes |
|---|---|---|
| `$006D` | Player horizontal position **in level** | High byte of full level X. Combine with `$0086` for sub-screen precision. |
| `$0086` | Player X position **on screen** | 0–255 across the visible screen. |
| `$03AD` | Player X within current screen offset | Same as `$0086` for most purposes. |
| `$00CE` | Player Y position on screen | Multiply by `$00B5` to get level Y. |
| `$00B5` | Player vertical screen position | Viewport row. `1` = visible (in viewport), `0` = above viewport, `>1` = below (falling into pit). |
| `$03B8` | Player Y within current screen | — |
| `$0057` | Player horizontal speed | Signed byte. `0xD8..0xFF` = moving left, `0x00` = stopped, `0x01..0x28` = moving right. |
| `$009F` | Player vertical velocity (whole pixels, signed) | `0xFB` = normal jump (going up), `0x05` = max fall speed. |

---

## HUD / scoring

| Address | What | Notes |
|---|---|---|
| `$075A` | **Lives** | Decrements on death. Game over when this rolls under 0 (i.e. dies with 0). Display value = `read_u8(0x075A)`. |
| `$075E` | **Coins** | BCD-style 0–99 single byte. Rolls to 0 + grants extra life every 100. |
| `$075F` | **World** (0-indexed) | `0` = World 1, `1` = World 2, ..., `7` = World 8. |
| `$0760` | **Level** (0-indexed within world) | `0` = first area (e.g. 1-1), `1` = second area (1-2), etc. Castle is typically `3`. |
| `$0750` | Area offset | Internal area index (see Data Crystal for the full lookup). |
| `$0773` | Level palette | `0x00` overworld, `0x01` underwater, `0x02` night, `0x03` underground, `0x04` castle. |
| `$07DD-$07E2` | **Mario's score** | 6 bytes BCD, one digit each: `[1000000][100000][10000][1000][100][10]`. Note: the "ones" digit is always 0 on the HUD. |
| `$07D7-$07DC` | High score | Same BCD format. |
| `$07D3-$07D8` | Luigi's score | 2P mode only. |
| `$07F8-$07FA` | **Game timer (BCD digits)** | The countdown clock in the HUD. `[hundreds][tens][ones]`. Drains during a level. |
| `$0787` | GameTimer Control Timer | Set to `0x02` to **freeze the in-game timer**. |
| `$07FC` | Game difficulty | Set after first clear — increments to Hard Mode rules (red enemies, etc.). |

> **Score reading helper (Lua)**:
> ```lua
> local function read_score()
>   local s = 0
>   for i = 0, 5 do
>     s = s * 10 + read_u8(0x07DD + i)
>   end
>   return s * 10   -- in-game score is always ×10 (ones digit is always 0)
> end
> ```

---

## Level layout / scrolling

| Address | What | Notes |
|---|---|---|
| `$071A` | Current screen in level | Increments as you cross screen boundaries. |
| `$071B` | Next screen in level | — |
| `$071C` | ScreenEdge X-position | Used to load the next screen. |
| `$071D` | Player x position triggering scroll | — |
| `$0723` | Scroll lock | `1` = locked (Bowser fight / warp zone / fortress); `0` = scroll allowed. |
| `$072C` | Current level layout index | — |
| `$06D6` | Warp-zone control | Determines which warp zone pipes go to. |

---

## Audio (for completion FX)

| Address | What | Notes |
|---|---|---|
| `$00FB` | Area music register | `0x01` overworld, `0x02` underwater, `0x04` underground, `0x08` castle, `0x10` star, `0x20` overworld transition, `0x80` silence. |
| `$00FC` | Event music register | `0x01` death, `0x02` game over, `0x04` ending theme, `0x08` castle ending, `0x20` level ending, `0x40` hurry-up jingle. |
| `$00FD` | Sound effect register 1 | `0x01` brick shatter, `0x02` Bowser fire. |
| `$00FE` | Sound effect register 2 | `0x01` coin, `0x02` powerup appears, `0x04` vine, `0x08` firework / Bullet Bill, `0x10` beep, `0x20` powerup collected, `0x40` 1up. |
| `$00FF` | Sound effect register 3 | `0x01` jump big, `0x02` bump, `0x04` stomp / swim, `0x08` kick, `0x10` pipe / damage, `0x20` fireball, `0x40` flagpole, `0x80` jump small. |

---

## Useful predicates

| What to detect | How |
|---|---|
| Game is in active gameplay (not title / demo / pause) | `read_u8(0x0770) == 0x02 and read_u8(0x0776) == 0x00` |
| Mario died (any cause) | `read_u8(0x000E) == 0x06` for ~60 frames; or watch for `$075A` to decrement. |
| Mario lost a life this frame (fail predicate) | Track previous `$075A`; fail when it decremented. |
| Reached the flagpole | `read_u8(0x001D) == 0x03` (sliding down flagpole). |
| Beat castle / reached axe | `$0772 == 0x04` (end-of-level animation). |
| Powered up | `read_u8(0x0756) >= 1`. |
| Stayed small (challenge gate) | `read_u8(0x0756) == 0x00` throughout. |
| Got a star | `read_u8(0x079F) > 0`. |
| Picked up X coins | `read_u8(0x075E) >= X` (capped at 99 + extra-life event). |
| In World N, Level M | `read_u8(0x075F) == (N-1) and read_u8(0x0760) == (M-1)`. |

---

## Open questions / to verify

- `$0754` vs `$0756` overlap — both report power state. Empirically `$0756` follows the HUD ("powered up?" answer); `$0754` flips earlier during transformation animations. **Use `$0756` unless you want to detect the transformation mid-animation.**
- `$07B1` "event music buffer" — the data-crystal note is ambiguous about whether freezing this also affects pit-fall deaths. Test before relying on it as an invincibility hack.

---

## Suggested first challenges

| Challenge | Win predicate | Fail predicate |
|---|---|---|
| **Beat 1-1 fastest time** | World/level rolls to 1-2 (`$075F == 0 and $0760 == 1`) | Lives decremented |
| **100 coins in any level** | `$075E` rolled from 99 → 0 (coin counter overflow + 1up event) | Lives decremented |
| **Beat 1-1 small Mario** | Reached flagpole (`$001D == 0x03`) | `$0756 > 0` at any point |
| **Beat 1-1 no jump** | Reached flagpole | `$001D != 0` (any airborne frame) — restrictive but achievable in 1-1 via vine? |
| **Beat 1-2 warp zone, fastest** | World rolls to W2/W3/W4 via pipe | Lives decremented |
| **High score in one life** | Survives X seconds | Lives decremented |
