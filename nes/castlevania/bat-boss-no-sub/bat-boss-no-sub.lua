-- Castlevania Phantom Bat — No Subweapon
-- Defeat the bat boss using the whip only. The rule is enforced by
-- writing 0 to the subweapon byte at setup, so the player literally
-- can't fire one even if they want to. Die once and the run fails.
--
-- Built on RcChallenge — savestate load, 3-2-1-GO countdown,
-- USER_PAUSED freeze, completion banner, leaderboard submission, and
-- R-anywhere-to-retry all come from the framework.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Castlevania)
-- ---------------------------------------------------------------------------
local USER_PAUSED  = 0x0022
local LIVES        = 0x002A
local HEALTH_REAL  = 0x0045
local SUBWEAPON    = 0x015B
local WHIP_LEVEL   = 0x0070
local BOSS_HEALTH  = 0x01A9   -- Phantom Bat HP

local FULL_HEALTH  = 0x40
local NO_WEAPON    = 0x00
local LONG_WHIP    = 0x02

-- ---------------------------------------------------------------------------
-- Game-specific freeze trick (Castlevania pause flag).
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(USER_PAUSED, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(USER_PAUSED, 0)
end

-- ---------------------------------------------------------------------------
-- Per-attempt state (the lives-decrement death detection needs a baseline
-- snapshotted at the start of each attempt, set in setup).
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate    = "savestates/batboss_no_subweapon.state",
    expected_rom_hashes = { "7A20C44F302FB2F1B7ADFFA6B619E3E1CAE7B546" },  -- Castlevania (USA, iNES file SHA1)
    countdown    = true,
    freeze_game  = freeze_game,
    release_game = release_game,

    -- Standardize the loadout: full HP, max whip, no subweapon.
    -- Snapshot lives AFTER any RAM writes for the death detector.
    setup = function(state)
        write_u8(HEALTH_REAL, FULL_HEALTH)
        write_u8(SUBWEAPON,   NO_WEAPON)
        write_u8(WHIP_LEVEL,  LONG_WHIP)
        prev_lives = read_u8(LIVES)
    end,

    win = function() return read_u8(BOSS_HEALTH) == 0 end,

    -- Lives decrement is the universal death signal in Castlevania.
    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        local simon_hp = read_u8(HEALTH_REAL)
        local boss_hp  = read_u8(BOSS_HEALTH)

        gui.text(10,  6, "TIME")
        hud.drawTime(48,  4, state.elapsed)
        gui.text(10, 30, "HP")
        hud.drawBar(28, 32, 70, simon_hp, FULL_HEALTH, "hp")
        gui.text(10, 46, "BAT")
        hud.drawDigits(48, 44, tostring(boss_hp))
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
