-- Dragon Warrior — Get to Level 2
-- The genre-busting challenge: how fast can you grind 7 XP and ding
-- Level 2? Slimes give 1 XP, Red Slimes 1, Drakees 2 — so 4-7 fights
-- depending on what spawns. Death sends the hero back to Tantegel
-- (HP rebuilds, no real penalty in vanilla), so the fail predicate
-- catches the brief HP=0 window before that teleport fires.
--
-- Built on RcChallenge — savestate, countdown, win banner, leaderboard
-- submission, and R-anywhere-to-retry come from the framework. Dragon
-- Warrior is turn-based so we don't need a per-game freeze byte; the
-- framework's input neutralization during banner phases is enough.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte
local read_u16 = memory.read_u16_le or function(addr)
    return read_u8(addr) + read_u8(addr + 1) * 256
end

-- ---------------------------------------------------------------------------
-- Memory map (US NES Dragon Warrior, both PRG0 and PRG1)
-- See nes/dragonwarrior/dragonwarrior_raminfo.md for the full reference.
-- ---------------------------------------------------------------------------
local XP_LO       = 0x00BA   -- Experience, 16-bit LE: $BA + $BB << 8
local CURRENT_HP  = 0x00C5
local CURRENT_MP  = 0x00C6
local PLAYER_LVL  = 0x00C7
local MAX_HP      = 0x00CA
local MAX_MP      = 0x00CB
-- Spells-learned bitfields. Bit 1 of $00CE = Hurt, bit 1 of $00CF = Hurtmore.
-- We OR the bits into whatever the savestate had so the player keeps any
-- other spells they were already carrying.
local SPELLS_BASE = 0x00CE
local SPELLS_EXT  = 0x00CF

local TARGET_LEVEL  = 2
local LOADOUT_MP    = 100
local HURT_BIT      = 0x02   -- bit 1 of $00CE
local HURTMORE_BIT  = 0x02   -- bit 1 of $00CF

-- ---------------------------------------------------------------------------
-- Audio handling during banner phases. DW is turn-based and lacks a
-- "user paused" byte like Castlevania has, so the game keeps animating
-- the music engine under the win / fail banners — which collides with
-- the leaderboard's completion music.
--
-- Writing 0 to $4015 (APU status, all-channels-disable) doesn't reliably
-- beat NesHawk's audio engine to the punch each frame. Instead we drop
-- to BizHawk's host-level sound toggle: client.SetSoundOn(false) cuts
-- emulator audio entirely. release_game flips it back on so the next
-- attempt's gameplay phase has its music. Both calls are wrapped in
-- pcall so a missing API in some future BizHawk version just degrades
-- gracefully (banner still draws; music just keeps playing).
-- ---------------------------------------------------------------------------
local function freeze_game()
    pcall(function() client.SetSoundOn(false) end)
    joypad.set({}, 1)
end

local function release_game()
    pcall(function() client.SetSoundOn(true) end)
end

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/get-to-level-2.state",
    -- Both common USA dumps share the same RAM layout, so accept either.
    expected_rom_hashes = {
        "6A50CE57097332393E0E8751924FD56456EF083C",  -- PRG0 (original)
        "1ECC63AAAC50A9612EAA8B69143858C3E48DD0AE",  -- PRG1 / Rev A
    },
    countdown           = true,
    freeze_game         = freeze_game,
    release_game        = release_game,

    -- Loadout: hand the hero 100 MP and the Hurt + Hurtmore spells so
    -- they can blast anything in the starting area. Hurtmore (5 MP per
    -- cast) one-shots slimes, red slimes, and drakees, so the run becomes
    -- "find an enemy, press SPELL, repeat 4 times". Pure dumb fun.
    -- Re-applied per attempt so retries always get the fresh loadout.
    setup = function(state)
        write_u8(MAX_MP,     LOADOUT_MP)
        write_u8(CURRENT_MP, LOADOUT_MP)
        write_u8(SPELLS_BASE, bit.bor(read_u8(SPELLS_BASE), HURT_BIT))
        write_u8(SPELLS_EXT,  bit.bor(read_u8(SPELLS_EXT),  HURTMORE_BIT))
    end,

    win = function() return read_u8(PLAYER_LVL) >= TARGET_LEVEL end,

    -- HP=0 at $00C5 lasts several frames before the engine fades to
    -- black and teleports the hero back to Tantegel. Per-frame polling
    -- catches the window. (DW doesn't have lives, so the universal
    -- "lives decrement" pattern from action games doesn't apply.)
    fail = function() return read_u8(CURRENT_HP) == 0 end,

    hud = function(state)
        local lvl    = read_u8(PLAYER_LVL)
        local xp     = read_u16(XP_LO)
        local hp     = read_u8(CURRENT_HP)
        local max_hp = read_u8(MAX_HP)
        local mp     = read_u8(CURRENT_MP)
        local max_mp = read_u8(MAX_MP)
        gui.text(10,  6, "TIME")
        hud.drawTime(48,  4, state.elapsed)
        gui.text(10, 24, "LVL " .. lvl)
        gui.text(70, 24, "XP "  .. xp .. "/7")
        -- Clamp the HP display to MaxHP — at level-up, $00C5 can briefly
        -- read above $00CA because HP is granted before MaxHP updates.
        local shown_hp = (max_hp > 0 and hp > max_hp) and max_hp or hp
        gui.text(10, 42, "HP "  .. shown_hp .. "/" .. max_hp)
        gui.text(10, 60, "MP "  .. mp .. "/" .. max_mp)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
