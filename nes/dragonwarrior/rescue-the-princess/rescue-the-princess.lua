-- Dragon Warrior — Rescue the Princess
-- Spawns at the green dragon's cave, the hero already maxed out (level
-- 30, full kit, all spells) per the savestate's loadout. Slay the
-- dragon, free Gwaelin, deliver her back to King Lorik in Tantegel
-- Throne Room. Death = run over.
--
-- Win  = $00DF bit 1 set (engine flips this when the king's "you've
--        returned my daughter!" dialogue finishes).
-- Fail = $00C5 (current HP) == 0. DW teleports a dead hero back to
--        Tantegel after a fade-out, but during the death window HP
--        sits at 0 for several frames — long enough for the
--        per-frame fail predicate to catch it.
--
-- Built on RcChallenge — savestate, countdown, win banner, leaderboard
-- submission, R-anywhere-to-retry come from the framework. DW is turn-
-- based so we don't need a per-game freeze byte; client.SetSoundOn(false)
-- during banner phases silences the overworld music so it doesn't
-- collide with the leaderboard's completion music (same pattern as
-- the other DW challenges).

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Dragon Warrior, both PRG0 and PRG1)
-- See nes/dragonwarrior/dragonwarrior_raminfo.md for the full reference.
-- ---------------------------------------------------------------------------
local CURRENT_HP = 0x00C5
local MAX_HP     = 0x00CA
local QUEST_FLAGS = 0x00DF   -- bit 0 = rescued princess (Gwaelin),
                             -- bit 1 = returned princess (to King Lorik).

local PRINCESS_RETURNED_BIT = 0x02

-- ---------------------------------------------------------------------------
-- Audio handling — host-level mute during banners. See get-to-level-2.lua
-- for the why; same approach.
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
    savestate           = "savestates/rescue-the-princess.state",
    expected_rom_hashes = {
        "6A50CE57097332393E0E8751924FD56456EF083C",  -- PRG0
        "1ECC63AAAC50A9612EAA8B69143858C3E48DD0AE",  -- PRG1 / Rev A
    },
    countdown           = true,
    freeze_game         = freeze_game,
    release_game        = release_game,

    -- Loadout is baked into the savestate (level-30 hero, all kit).
    -- No setup work needed; framework defaults to a noop.

    -- Win = the king's quest-flag for "princess returned" flips on.
    -- Bit 1 of $00DF is set in the dialogue routine after Gwaelin walks
    -- behind the king, well after the runner can't influence the outcome.
    win = function()
        return bit.band(read_u8(QUEST_FLAGS), PRINCESS_RETURNED_BIT) ~= 0
    end,

    -- Death window catch — HP sits at 0 for several frames before the
    -- engine fades to black and warps the hero back to Tantegel.
    fail = function() return read_u8(CURRENT_HP) == 0 end,

    hud = function(state)
        local hp     = read_u8(CURRENT_HP)
        local max_hp = read_u8(MAX_HP)
        local flags  = read_u8(QUEST_FLAGS)
        local rescued = (bit.band(flags, 0x01) ~= 0) and "Y" or "N"
        gui.text(10,  6, "TIME")
        hud.drawTime(48,  4, state.elapsed)
        local shown_hp = (max_hp > 0 and hp > max_hp) and max_hp or hp
        gui.text(10, 24, "HP " .. shown_hp .. "/" .. max_hp)
        gui.text(10, 42, "PRINCESS " .. rescued)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
