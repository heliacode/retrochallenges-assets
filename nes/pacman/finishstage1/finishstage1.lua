-- Pac-Man (NES, Namco) — Finish Stage 1
-- Clear all 244 dots on the Cherry board. The win fires the moment the
-- level byte ticks over to stage 2. Three lives, but one death ends
-- the run — make every dot count.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8 = memory.read_u8 or memory.readbyte

-- ---------------------------------------------------------------------------
-- Memory map (NES Pac-Man — derived from the 1985 Namco FDS RAM map)
-- Source: Data Crystal — Pac-Man (NES, FDS) / RAM map
-- https://datacrystal.tcrf.net/wiki/Pac-Man_(NES,_Famicom_Disk_System)/RAM_map
--
-- Same caveat as get-2000-pts: the 1993 Namco USA NES release is
-- believed to share the FDS port's layout but isn't independently
-- documented. Verify with BizHawk's RAM Watch if anything looks off.
-- ---------------------------------------------------------------------------
local SCORE_TENS         = 0x0070
local SCORE_HUNDREDS     = 0x0071
local SCORE_THOUSANDS    = 0x0072
local SCORE_TENTHOUSANDS = 0x0073
local SCORE_HUNTHOUSANDS = 0x0074
local SCORE_MILLIONS     = 0x0075

local LIVES             = 0x0067
local LEVEL             = 0x0068
local PELLETS_REMAINING = 0x006A

local function read_score()
    return read_u8(SCORE_TENS)         * 10
         + read_u8(SCORE_HUNDREDS)     * 100
         + read_u8(SCORE_THOUSANDS)    * 1000
         + read_u8(SCORE_TENTHOUSANDS) * 10000
         + read_u8(SCORE_HUNTHOUSANDS) * 100000
         + read_u8(SCORE_MILLIONS)     * 1000000
end

-- ---------------------------------------------------------------------------
-- Per-attempt baselines, set in setup() so retries reset cleanly.
-- ---------------------------------------------------------------------------
local prev_lives    = 0
local initial_level = 0

challenge.run{
    savestate = "savestates/finishstage1.State",
    -- Same ROM as get-2000-pts; once the SHA1 is captured for either
    -- challenge it can be pasted into both.
    expected_rom_hashes = {},

    setup = function(state)
        emu.frameadvance()
        prev_lives    = read_u8(LIVES)
        initial_level = read_u8(LEVEL)
    end,

    -- Win the moment the level byte advances. Robust against the byte
    -- starting at 0 vs 1 and against any in-game animation between
    -- "last pellet eaten" and "stage 2 maze drawn". Player sees the
    -- transition animation; framework's 60-frame play-on plays the
    -- celebration over the start of stage 2.
    win = function() return read_u8(LEVEL) > initial_level end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        gui.text(10,  6, "SCORE")
        hud.drawScore(48,  4, read_score(), 0)
        gui.text(10, 24, "DOTS")
        gui.text(48, 24, tostring(read_u8(PELLETS_REMAINING)))
        gui.text(10, 42, "LIVES")
        gui.text(48, 42, tostring(read_u8(LIVES)))
        gui.text(10, 60, "TIME")
        hud.drawTime(48, 58, state.elapsed)
    end,

    result = function(state)
        return {
            score          = read_score(),
            completionTime = state.elapsed,
        }
    end,
}
