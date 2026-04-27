-- Mega Man 2 — Metal Man Boss Fight
-- Loaded loadout: full HP (28), buster equipped. Defeat Metal Man as
-- fast as possible. Die once and the run is over.
--
-- Built on RcChallenge — savestate, countdown, win banner, leaderboard
-- submission, and R-anywhere-to-retry come from the framework.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Mega Man 2)
-- See nes/megaman2/RAM.md for the full reference.
-- ---------------------------------------------------------------------------
local PLAYER_HP      = 0x06C0
local BOSS_HP        = 0x06C1
local LIVES          = 0x00A8
local CURRENT_WEAPON = 0x00A9
local DIFFICULTY     = 0x00CB

local MAX_HP   = 0x1C   -- 28
local BUSTER   = 0x00
local NORMAL   = 0x00   -- standardized "Difficult" mode

-- ---------------------------------------------------------------------------
-- Per-attempt state (lives baseline for the death detector).
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/metalman-boss.state",
    expected_rom_hashes = { "2290D8D839A303219E9327EA1451C5EEA430F53D" },  -- Mega Man 2 (USA, iNES file SHA1)

    setup = function(state)
        write_u8(PLAYER_HP,      MAX_HP)
        write_u8(CURRENT_WEAPON, BUSTER)
        write_u8(DIFFICULTY,     NORMAL)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    win = function() return read_u8(BOSS_HP) == 0 end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        -- Just the timer with a translucent backing — Metal Man's room
        -- is busy enough already. "0:00.000" (7 glyphs) at 18x22 with
        -- 14px advance is ~102px wide; 4px padding on each side.
        gui.drawRectangle(6, 4, 110, 28, 0xc0000000, 0xc0000000)
        hud.drawTime(10, 8, state.elapsed)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
