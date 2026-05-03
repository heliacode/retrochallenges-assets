-- Pac-Man (NES, Namco) — Get 2000 Points
-- Score 2000+ in a single game. Three lives by default; run ends the
-- moment Pac-Man dies (lives counter decrements). Same playbook as
-- Donkey Kong's 2000pts: digit-per-byte score read, lives-counter
-- death detector, win on threshold.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (NES Pac-Man — derived from the 1985 Namco FDS RAM map)
-- Source: Data Crystal — Pac-Man (NES, Famicom Disk System) / RAM map
-- https://datacrystal.tcrf.net/wiki/Pac-Man_(NES,_Famicom_Disk_System)/RAM_map
--
-- The 1993 Namco USA NES release is widely believed to be derived from
-- the FDS port and share the same memory layout. If a watch-window
-- check shows score / lives sitting at different addresses on this
-- specific dump, paste the actual SHA1 from the Lua console into
-- `expected_rom_hashes` below and adjust these constants.
-- ---------------------------------------------------------------------------
-- Score is six SEPARATE bytes — one decimal digit per byte (NOT BCD-
-- packed two-per-byte like Castlevania / Donkey Kong). Arcade Pac-Man
-- scores always end in 0, so $0070 holds the TENS digit (not the ones).
local SCORE_TENS         = 0x0070  -- 10^1
local SCORE_HUNDREDS     = 0x0071  -- 10^2
local SCORE_THOUSANDS    = 0x0072  -- 10^3
local SCORE_TENTHOUSANDS = 0x0073  -- 10^4
local SCORE_HUNTHOUSANDS = 0x0074  -- 10^5
local SCORE_MILLIONS     = 0x0075  -- 10^6

local LIVES = 0x0067   -- "Current Lives" — decrements on death

local TARGET_SCORE = 2000

-- ---------------------------------------------------------------------------
-- Score decode. Each byte is a single digit 0-9; total = sum * place value.
-- ---------------------------------------------------------------------------
local function read_score()
    return read_u8(SCORE_TENS)         * 10
         + read_u8(SCORE_HUNDREDS)     * 100
         + read_u8(SCORE_THOUSANDS)    * 1000
         + read_u8(SCORE_TENTHOUSANDS) * 10000
         + read_u8(SCORE_HUNTHOUSANDS) * 100000
         + read_u8(SCORE_MILLIONS)     * 1000000
end

-- ---------------------------------------------------------------------------
-- Per-attempt state. Set in setup() so a retry resets the death baseline.
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate = "savestates/get-2000-pts.State",
    -- expected_rom_hashes intentionally empty until we capture a canonical
    -- SHA1 from the Lua console on first launch. Add it then to lock the
    -- challenge to the correct ROM dump.
    expected_rom_hashes = {},

    setup = function(state)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    win = function() return read_score() >= TARGET_SCORE end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        gui.text(10,  6, "SCORE")
        hud.drawScore(48,  4, read_score(), TARGET_SCORE)
        gui.text(10, 24, "LIVES")
        gui.text(48, 24, tostring(read_u8(LIVES)))
        gui.text(10, 42, "TIME")
        hud.drawTime(48, 40, state.elapsed)
    end,

    result = function(state)
        return {
            score          = read_score(),
            completionTime = state.elapsed,
        }
    end,
}
