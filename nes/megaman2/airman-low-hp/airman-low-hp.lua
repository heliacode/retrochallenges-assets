-- Mega Man 2 — Air Man, Low HP Clutch
-- Mega Man enters the boss room at half HP (14/28). Clear Air Man
-- without dying. The savestate captures the moment Mega Man steps
-- into the arena; setup pins his HP to exactly 14 so the run is
-- standardized regardless of what the player had on entry.
--
-- Built on RcChallenge — savestate, countdown, win banner, retry,
-- ROM hash check, leaderboard submission all come from the framework.

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
local HALF_HP  = 0x0E   -- 14
local BUSTER   = 0x00
local NORMAL   = 0x00

-- ---------------------------------------------------------------------------
-- Per-attempt state (lives baseline for the death detector).
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/airman-low-hp.state",
    expected_rom_hashes = { "2290D8D839A303219E9327EA1451C5EEA430F53D" },  -- Mega Man 2 (USA, iNES file SHA1)

    setup = function(state)
        write_u8(PLAYER_HP,      HALF_HP)        -- pinned 50% so the run is standardized
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
        gui.drawRectangle(6, 4, 110, 28, 0xc0000000, 0xc0000000)
        hud.drawTime(10, 8, state.elapsed)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
