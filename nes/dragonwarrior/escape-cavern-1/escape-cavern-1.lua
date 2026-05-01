-- Dragon Warrior — Escape Cavern 1
-- Level 1, no spells, no items, no XP — just a hero with 15 HP and the
-- weak default whip (basically nothing) trying to find the way out of
-- a cave. Win the moment you set foot back on the overworld map.
--
-- No fail predicate: dying just teleports you to Tantegel; you're free
-- to walk the long way back out from there if it goes wrong. The clock
-- keeps running through that detour, so dying is its own penalty.
--
-- Built on RcChallenge — savestate, countdown, win banner, leaderboard
-- submission, R-anywhere-to-retry. Audio handling matches the level-2
-- challenge: client.SetSoundOn(false) during banners so completion
-- music isn't drowned by the overworld theme.

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
local XP_LO       = 0x00BA   -- 16-bit LE
local CURRENT_HP  = 0x00C5
local CURRENT_MP  = 0x00C6
local PLAYER_LVL  = 0x00C7
local MAX_HP      = 0x00CA
local MAX_MP      = 0x00CB
local KEYS        = 0x00BF
local HERBS       = 0x00C0
-- Inventory: 8 slots packed two-per-byte across $00C1..$00C4. Each slot
-- holds one item ID (low nibble = even slot, high nibble = odd slot).
-- We need 6 torches → fill slots 0..5 with item ID 1.
local INV_BASE    = 0x00C1
local ITEM_TORCH  = 0x1
local SPELLS_BASE = 0x00CE   -- bits 0..7: Heal/Hurt/Sleep/Radiant/Stopspell/Outside/Return/Repel
local SPELLS_EXT  = 0x00CF   -- bits 0..7: Healmore/Hurtmore/SecretStairs/RainbowBridge/...

-- $0045 holds the current map ID. $01 = overworld.
local MAP_ID    = 0x0045
local MAP_WORLD = 0x01

-- Level-1 baseline values. Setting MaxHP explicitly avoids inheriting
-- whatever the savestate happened to have, so retries are deterministic.
local LV1_LEVEL  = 1
local LV1_MAX_HP = 15

-- ---------------------------------------------------------------------------
-- Audio handling — see escape-cavern-1's sibling challenges for context.
-- BizHawk's host-level mute beats the NesHawk APU race during banners.
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
    savestate           = "savestates/escape-cavern-1.state",
    expected_rom_hashes = {
        "6A50CE57097332393E0E8751924FD56456EF083C",  -- PRG0
        "1ECC63AAAC50A9612EAA8B69143858C3E48DD0AE",  -- PRG1 / Rev A
    },
    countdown           = true,
    freeze_game         = freeze_game,
    release_game        = release_game,

    -- Strip the player down to level-1 nothing every attempt: 0 XP, 0 MP,
    -- no spells learned, no keys, no herbs, just 15 HP. The 6 torches go
    -- into slots 0..5 — DW caves are pitch-black at the default visibility
    -- radius, so without torches you can't really navigate.
    -- Re-applied on retry so the runner doesn't accidentally carry XP
    -- forward from a previous attempt that ended in a wandering retreat.
    setup = function(state)
        write_u8(PLAYER_LVL,  LV1_LEVEL)
        write_u8(XP_LO,       0)
        write_u8(XP_LO + 1,   0)
        write_u8(MAX_HP,      LV1_MAX_HP)
        write_u8(CURRENT_HP,  LV1_MAX_HP)
        write_u8(MAX_MP,      0)
        write_u8(CURRENT_MP,  0)
        write_u8(SPELLS_BASE, 0)
        write_u8(SPELLS_EXT,  0)
        write_u8(KEYS,        0)
        write_u8(HERBS,       0)
        -- Inventory slots 0..5 = Torch; slots 6..7 empty.
        local pair = bit.bor(ITEM_TORCH, bit.lshift(ITEM_TORCH, 4))   -- 0x11
        write_u8(INV_BASE,     pair)   -- slots 0,1
        write_u8(INV_BASE + 1, pair)   -- slots 2,3
        write_u8(INV_BASE + 2, pair)   -- slots 4,5
        write_u8(INV_BASE + 3, 0)      -- slots 6,7
    end,

    -- Win = the engine's map byte flips to the overworld value. Whether
    -- we got there by climbing the cave stairs or by dying and wandering
    -- out from Tantegel, the predicate fires the same.
    win = function() return read_u8(MAP_ID) == MAP_WORLD end,

    -- No fail predicate — death just delays the run.
    -- (Framework defaults fail to always_false when omitted.)

    hud = function(state)
        local lvl    = read_u8(PLAYER_LVL)
        local xp     = read_u16(XP_LO)
        local hp     = read_u8(CURRENT_HP)
        local max_hp = read_u8(MAX_HP)
        local mapid  = read_u8(MAP_ID)
        gui.text(10,  6, "TIME")
        hud.drawTime(48,  4, state.elapsed)
        gui.text(10, 24, "LVL " .. lvl .. "  XP " .. xp)
        local shown_hp = (max_hp > 0 and hp > max_hp) and max_hp or hp
        gui.text(10, 42, "HP "  .. shown_hp .. "/" .. max_hp)
        gui.text(10, 60, "MAP " .. string.format("%02X", mapid))
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
