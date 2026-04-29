-- Castlevania — Escape the Fish-People
-- Simon spawns deep in the swampy sunken-city area with a quarter-bar
-- of HP and has to climb the stairs out before the merman / fish-men
-- knock him into the water for good.
--
-- Win  = the engine's Floor byte ($0046) increments past its captured
--        value (Simon completed a stair traversal).
-- Fail = lives counter decrements (universal death detection — handles
--        merman knockback into pits, instakill water, HP zero, etc.).
--
-- Built on RcChallenge — savestate, countdown, win banner, leaderboard
-- submission, and R-anywhere-to-retry come from the framework.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Castlevania)
-- See nes/castlevania/castlevania_raminfo.md
-- ---------------------------------------------------------------------------
local USER_PAUSED  = 0x0022
local LIVES        = 0x002A
local SIMON_Y      = 0x003F   -- (unused in win predicate but documented for HUD use)
local FLOOR        = 0x0046   -- Stair-floor counter; increments when Simon
                              -- completes a staircase transition.
local HEALTH_REAL  = 0x0045

-- "1 bar of HP left" — Simon's HP runs 0–64; the on-screen bar has 16
-- ticks at 4 HP each, so 1 visible tick = 4 HP. Brutal: most enemies
-- one-shot Simon at this HP, hence the "Medium" rating leaning hard.
local START_HP   = 0x04

-- ---------------------------------------------------------------------------
-- Game-specific freeze trick
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(USER_PAUSED, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(USER_PAUSED, 0)
end

-- ---------------------------------------------------------------------------
-- Per-attempt state.
-- ---------------------------------------------------------------------------
local prev_lives    = 0
local floor_at_start = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/escape-the-fish-people.state",
    expected_rom_hashes = { "7A20C44F302FB2F1B7ADFFA6B619E3E1CAE7B546" },  -- Castlevania (USA, iNES file SHA1)
    countdown           = true,
    freeze_game         = freeze_game,
    release_game        = release_game,

    setup = function(state)
        write_u8(HEALTH_REAL, START_HP)
        emu.frameadvance()
        prev_lives     = read_u8(LIVES)
        floor_at_start = read_u8(FLOOR)
    end,

    win = function() return read_u8(FLOOR) > floor_at_start end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        gui.text(10, 6, "TIME")
        hud.drawTime(48, 4, state.elapsed)
        gui.text(10, 24, "HP")
        gui.text(48, 24, tostring(read_u8(HEALTH_REAL)) .. "/64")
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
