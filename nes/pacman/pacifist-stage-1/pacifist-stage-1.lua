-- Pac-Man (NES, Namco) — Pacifist Stage 1
-- Clear all 244 dots on the Cherry board WITHOUT eating any ghost.
-- Power pellets are fine (you might need them to escape), but the
-- moment you chomp a frightened ghost, the run ends. Death also ends
-- the run.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8 = memory.read_u8 or memory.readbyte

-- ---------------------------------------------------------------------------
-- Memory map (NES Pac-Man — Namco FDS layout, see other Pac-Man challenges)
-- ---------------------------------------------------------------------------
local SCORE_TENS         = 0x0070
local SCORE_HUNDREDS     = 0x0071
local SCORE_THOUSANDS    = 0x0072
local SCORE_TENTHOUSANDS = 0x0073
local SCORE_HUNTHOUSANDS = 0x0074
local SCORE_MILLIONS     = 0x0075
local LIVES              = 0x0067
local LEVEL              = 0x0068
local PELLETS_REMAINING  = 0x006A

local function read_score()
    return read_u8(SCORE_TENS)         * 10
         + read_u8(SCORE_HUNDREDS)     * 100
         + read_u8(SCORE_THOUSANDS)    * 1000
         + read_u8(SCORE_TENTHOUSANDS) * 10000
         + read_u8(SCORE_HUNTHOUSANDS) * 100000
         + read_u8(SCORE_MILLIONS)     * 1000000
end

-- Same ghost-eat detector as Eat Blinky / 4-ghost combo: a single-frame
-- score delta in {200, 400, 800, 1600} can only come from a ghost-eat
-- in arcade-faithful Pac-Man scoring.
local GHOST_EAT_SCORE_DELTAS = { [200] = true, [400] = true, [800] = true, [1600] = true }

-- Per-attempt baselines.
local prev_score    = 0
local prev_lives    = 0
local initial_level = 0

challenge.run{
    savestate = "savestates/pacifist-stage-1.State",
    expected_rom_hashes = {},
    countdown = false,

    setup = function(state)
        emu.frameadvance()
        prev_score    = read_score()
        prev_lives    = read_u8(LIVES)
        initial_level = read_u8(LEVEL)
    end,

    -- Win when the level byte advances past the starting value (same
    -- predicate as Finish Stage 1 — robust against zero- vs one-indexed
    -- and against the cleared-stage transition animation).
    win = function() return read_u8(LEVEL) > initial_level end,

    fail = function()
        -- Death ends the run.
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now

        -- Pacifist constraint: any ghost-eat ends the run too.
        local cur_score = read_score()
        local delta     = cur_score - prev_score
        prev_score      = cur_score
        if GHOST_EAT_SCORE_DELTAS[delta] then return true end

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
