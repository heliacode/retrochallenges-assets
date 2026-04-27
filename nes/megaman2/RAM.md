# Mega Man 2 (NES) — RAM reference

Working reference for authoring RetroChallenges challenges on Mega Man 2 (US/JP NES, MMC1).

**Sources:**
- `plasticsmoke/megaman2-disassembly-ca65` — Mesen-verified annotated ca65 disassembly. **Primary source for everything below.**
- [Data Crystal RAM map](https://datacrystal.tcrf.net/wiki/Mega_Man_2:RAM_map) — community-curated, used as a cross-check. (One of its claims about `$002A` turned out to be incorrect; the disassembly version is what's documented here.)

All addresses below are confirmed unless explicitly marked. Constant names use the disassembly's labels.

---

## Player

| Address | Label | What | Notes |
|---|---|---|---|
| `$06C0` | `ent_hp + 0` | Mega Man HP | Max = `MAX_HP = 0x1C` (28). Damage subtracts. |
| `$00A8` | — | Lives remaining | Display glitches if `> 0x64`. |
| `$00A7` | — | E-Tanks held | Can store > `4` but breaks the password screen. |
| `$004B` | — | I-frames timer | Counts down 1/frame. `> 0` = invincible. |
| `$00CB` | — | Difficulty | `0x00` = US Difficult / JP Normal, `0x01` = US Normal (a damage-halved beginner mode unique to the US release). Pin to `0x00` in `setup` to standardize. |

### Position / motion

| Address | Label | What | Notes |
|---|---|---|---|
| `$0460` | `ent_x_px + 0` | Mega Man X (pixel) | Within current screen. |
| `$04A0` | `ent_y_px + 0` | Mega Man Y (pixel) | — |
| `$0440` | `ent_x_screen + 0` | X screen index | Increments when X rolls over. |
| `$04E0` | `ent_state + 0` | Player AI state | — |
| `$0035` | `is_on_ground` | On-ground flag | Nonzero = standing on a solid tile. **Useful for "no-jumping" challenges.** |
| `$0036` | `general_timer` | Animation / shoot timer | — |
| `$003D` | `weapon_fire_dir` | Firing direction | Nonzero while shooting. |
| `$002D` | `player_screen_x` | Player X relative to camera | — |

### Tile under Mega Man

| Address | Label | What | Value mapping |
|---|---|---|---|
| `$0032` | `floor_tile_type` | Tile at feet | `0x00` air, `0x01` ground, `0x02` ladder, `0x03` instadeath, `0x04` water, `0x05` right conveyor, `0x06` left conveyor, `0x07` ice |
| `$0033` | `floor_collision_result` | Collision bits | — |

> **`$0032 == 0x03`** is the cleanest "Mega Man just touched a death tile" signal — useful as a fail predicate for pit / spike / death-laser challenges.

---

## Weapons

### Currently-equipped weapon — `$00A9` (`current_weapon`)

A single byte holds the **selected weapon ID**. The pause menu writes here.

| Hex | Constant | Weapon |
|---|---|---|
| `0x00` | (buster) | Mega Buster (default) |
| `0x01` | `WEAPON_ATOMIC_FIRE` | **Atomic Fire** (Heat Man) |
| `0x02` | `WEAPON_AIR_SHOOTER` | **Air Shooter** (Air Man) |
| `0x03` | `WEAPON_LEAF_SHIELD` | **Leaf Shield** (Wood Man) |
| `0x04` | `WEAPON_BUBBLE_LEAD` | **Bubble Lead** (Bubble Man) |
| `0x05` | `WEAPON_QUICK_BOOM` | **Quick Boomerang** (Quick Man) |
| `0x06` | `WEAPON_TIME_STOPPER` | **Time Stopper** (Flash Man) |
| `0x07` | `WEAPON_METAL_BLADE` | **Metal Blade** (Metal Man) |
| `0x08` | `WEAPON_CRASH_BOMBER` | **Crash Bomber** (Crash Man) |

**Enforcement patterns:**
- "Buster only": fail predicate = `read_u8(0x00A9) != 0x00`.
- "Use only Metal Blade": fail predicate = `read_u8(0x00A9) != 0x00 and read_u8(0x00A9) != 0x07`.
- Or: write the desired weapon in `setup` and overwrite back to it every frame in `on_frame` to literally prevent switching.

### Unlocked-weapon bitfield — `$009A`

Each bit set = that weapon has been picked up (i.e. that Robot Master has been defeated). The byte stores all 8 flags at once.

| Bit | Hex | Weapon | Granted by defeating |
|---|---|---|---|
| 0 | `0x01` | Atomic Fire | Heat Man |
| 1 | `0x02` | Air Shooter | Air Man |
| 2 | `0x04` | Leaf Shield | Wood Man |
| 3 | `0x08` | Bubble Lead | Bubble Man |
| 4 | `0x10` | Quick Boomerang | Quick Man |
| 5 | `0x20` | Time Stopper | Flash Man |
| 6 | `0x40` | Metal Blade | Metal Man |
| 7 | `0x80` | Crash Bomber | Crash Man |

> **Useful trick:** `$009A == 0xFF` ⇔ "all 8 Robot Masters defeated". Makes "all RMs in one sitting" a one-line win predicate.

### Per-weapon ammo — `$009C`–`$00A3`

Max ammo = `MAX_HP = 0x1C` (28).

| Address | Weapon |
|---|---|
| `$009C` | Atomic Fire |
| `$009D` | Air Shooter |
| `$009E` | Leaf Shield |
| `$009F` | Bubble Lead |
| `$00A0` | Quick Boomerang |
| `$00A1` | Time Stopper |
| `$00A2` | Metal Blade |
| `$00A3` | Crash Bomber |

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

---

## Bosses & enemies

### Boss (entity slot 1)

| Address | Label | What | Notes |
|---|---|---|---|
| `$06C1` | `boss_hp` | Boss HP | All 8 Robot Masters + Wily-stage bosses share this slot. Max usually `MAX_HP = 0x1C` (28). **Win condition: `read_u8(0x06C1) == 0`.** |
| `$0461` | `boss_x_px` | Boss X | Within screen. |
| `$04A1` | `boss_y_px` | Boss Y | — |
| `$04E1` | `boss_ai_state` | Boss AI sub-state | Useful for tracking phases. |
| `$0421` | `boss_flags` | Boss flags | bit 7 = active, 6 = facing. |
| `$05A6` | `boss_spawn_timer` | Spawn / intro countdown | Nonzero during the boss-fight intro animation. **Useful to gate the timer until the actual fight starts.** |
| `$05A8` | `boss_hit_timer` | Hit-stun timer | Set to `0x12` when the boss takes a hit; counts down. |
| `$05AA` | `boss_hit_count` | Lifetime hit counter | Increments per hit; useful for "X hits to kill" challenges. |

### Enemies

| Address | Label | What |
|---|---|---|
| `$06C2`–`$06DF` | `ent_hp + N` | Enemy HPs across 32 entity slots (slot 0 = player, 1 = boss, 2+ = enemies). |

---

## Stage / level state

| Address | Label | What | Notes |
|---|---|---|---|
| `$002A` | `current_stage` | **Current stage index** (range `0x00–0x0D`) | See full mapping below. Set this in `setup` to "warp" to a stage, but you also need the engine to be in a state that respects the change — testing required. |
| `$002C` | `game_substate` | Game sub-state | Includes weapon-select state. Useful to gate things on "is the player actually playing right now". |
| `$0038` | `current_screen` | Current room/screen index within the stage | Increments as the player moves between screens. **Useful as a progress indicator** ("reached screen 5" etc.). |
| `$0037` | `transition_type` | Room transition request | `0x00` = none, `bit0 set` = vertical, **`0x03` = entering boss room**. |
| `$0029` | `current_bank` | Currently switched PRG bank | Each stage has a dedicated bank; can be a sanity check. |
| `$001C` | `frame_counter` | Frame counter | Incremented every NMI. **Note:** does not pause when the game is paused. For a "respects pause" timer, use `$0F39` (gameplay frame counter). |

### Stage index mapping (`$002A`)

| Hex | Constant | Stage | Bank |
|---|---|---|---|
| `0x00` | `STAGE_HEAT_MAN` | Heat Man | `$03` |
| `0x01` | `STAGE_AIR_MAN` | Air Man | `$04` |
| `0x02` | `STAGE_WOOD_MAN` | Wood Man | `$01` |
| `0x03` | `STAGE_BUBBLE_MAN` | Bubble Man | `$07` |
| `0x04` | `STAGE_QUICK_MAN` | Quick Man | `$06` |
| `0x05` | `STAGE_FLASH_MAN` | Flash Man | `$00` |
| `0x06` | `STAGE_METAL_MAN` | Metal Man | `$05` |
| `0x07` | `STAGE_CRASH_MAN` | Crash Man | `$02` |
| `0x08` | `STAGE_WILY_1` | Wily 1 — Mecha Dragon | `$08` |
| `0x09` | `STAGE_WILY_2` | Wily 2 — Picopico-kun | `$08` |
| `0x0A` | `STAGE_WILY_3` | Wily 3 — Guts-Dozer | `$09` |
| `0x0B` | `STAGE_WILY_4` | Wily 4 — Boobeam Trap | `$09` |
| `0x0C` | `STAGE_WILY_5` | Wily 5 — Wily Machine | `$09` |
| `0x0D` | `STAGE_WILY_6` | Wily 6 — Alien | (special) |

> **`current_stage >= 0x08`** ⇔ player is in a Wily fortress stage (constant `WILY_STAGE_START`).
>
> ⚠ **Note on Data Crystal:** that wiki's `$002A` mapping (`0x00 = Wily, 0x01–0x08 clockwise from Bubble Man`) is **incorrect / refers to a different byte** (probably the cursor sprite position on the select screen). The disassembly mapping above is authoritative — it's the value the engine uses to load stage data.

---

## Camera

| Address | Label | What | Notes |
|---|---|---|---|
| `$001B` | — | Camera state | `0x00` default, `0x01` changing nametable, `0x02` freeze before/after scroll, `0x80` scrolling vertically. |
| `$001F` | `scroll_x` | Camera X position | — |
| `$0020` | `nametable_select` | Active nametable | bit 0. |
| `$0022` | `scroll_y` | Camera Y position | — |
| `$0021` | `scroll_y_page` | Scroll Y page | — |

---

## Input

| Address | Label | What | Bitmask |
|---|---|---|---|
| `$0023` | `controller_1` | P1 buttons (current frame) | A=0x80 B=0x40 Sel=0x20 Start=0x10 U=0x08 D=0x04 L=0x02 R=0x01 |
| `$0024` | `controller_2` | P2 buttons | same |
| `$0025` | `p1_prev_buttons` | P1 buttons (previous frame) | — |
| `$0027` | `p1_new_presses` | P1 buttons that went down THIS frame | edge-trigger; "Crash Man's AI checks this for jump code" |

---

## Sound

| Address | Label | What |
|---|---|---|
| `$0066` | — | SFX strobe — write `0x01` to play SFX whose ID is at `$0580` |
| `$0067` | — | Music strobe — write `0x01` to play music whose ID is at `$0000` |
| `$0580` | — | SFX queue |

---

## Graphics

| Address | What |
|---|---|
| `$0200`–`$02FF` | Sprite memory (DMA'd to OAM). Don't touch. |
| `$0354` | Palette cycling pattern — level-dependent |
| `$0355` | Palette cycling speed — `0x00` = no cycling |
| `$0356`–`$0365` | Background palette memory |
| `$0366`–`$0375` | Sprite palette memory |
| `$0F39` | Gameplay frame counter (pauses on pause menu — different from `$001C`) |

---

## Constants worth knowing

| Name | Value | Meaning |
|---|---|---|
| `MAX_HP` | `0x1C` (28) | Player HP max, boss HP max, and weapon-energy max. |
| `WILY_STAGE_START` | `0x08` | Stage indices `>=` this are Wily fortress. |
| `ENT_FLAG_ACTIVE` | `0x80` | bit 7 of an entity flags byte ⇒ entity is alive. |
| `ENT_FLAG_FLIP_H` | `0x40` | Facing left. |
| `ENT_FLAG_WEAPON_HIT` | `0x02` | Was hit by a weapon this frame. |

---

## Authoring patterns

### Universal death detection

Mega Man dies when:
- HP reaches 0: `read_u8(0x06C0) == 0`
- He touches a death tile: `read_u8(0x0032) == 0x03`
- (Bottomless pit: technically separate, but causes HP=0 so the first check still fires.)

Combine with a "previous lives counter" check (lives at `$00A8`) for the most universal signal:

```lua
fail = function()
    local now = read_u8(0x00A8)
    if now < prev_lives then return true end
    prev_lives = now
    return false
end
```

### Standardize the loadout

```lua
setup = function(state)
    write_u8(0x06C0, 0x1C)   -- full HP
    write_u8(0x009A, 0xFF)   -- all weapons unlocked
    write_u8(0x009B, 0x07)   -- all 3 items unlocked
    for addr = 0x009C, 0x00A3 do write_u8(addr, 0x1C) end  -- full ammo
    write_u8(0x00A8, 3)      -- 3 lives
    write_u8(0x00CB, 0x00)   -- difficulty: Difficult (standard)
    write_u8(0x00A9, 0x00)   -- equip the buster
    prev_lives = read_u8(0x00A8)
end
```

### Lock the weapon (e.g. "buster only")

```lua
on_frame = function(state)
    write_u8(0x00A9, 0x00)   -- force buster every frame; pause-menu cycle is reverted
end
```

### "All 8 Robot Masters" win

```lua
win = function()
    return read_u8(0x009A) == 0xFF
end
```

### Boss-room timer freeze

```lua
-- Don't start counting until the boss-fight intro is over and the boss is active.
local timer_started = false
local fight_start_frame = nil

on_frame = function(state)
    if not timer_started then
        local in_boss_room = read_u8(0x0037) == 0x03 or read_u8(0x05A6) == 0  -- past the spawn intro
        local boss_active  = (read_u8(0x0421) & 0x80) ~= 0
        if in_boss_room and boss_active then
            fight_start_frame = state.absolute_frame
            timer_started = true
        end
    end
end
```

---

## Suggested challenges, ranked by ease

| Challenge | Required addresses | Status |
|---|---|---|
| Speedrun any RM stage (savestate at start) | `$06C0`, `$06C1`, `$00A8` | ready |
| Cross Quick Man's death-laser corridor | `$06C0`, `$0032`, `$04A0`/`$04A1` | ready |
| All 8 Robot Masters in one sitting | `$009A`, `$00A8` | ready |
| No-damage Heat Man | `$06C0`, `$06C1`, `$00A8` | ready |
| **Buster-only Heat Man** | `$00A9` (now confirmed) | ready |
| **Use only Metal Blade for Wily 1** | `$00A9`, `$06C1` | ready |
| **Speedrun any stage from boot** (no savestate) | `$002A`, `$002C`, controller writes | needs Start-press automation in setup |
