-- Pac-Man (NES, Namco) — Eat Blinky
-- Same starting state as Finish Stage 1. Win the moment you eat the
-- red ghost: snag a power pellet, chase Blinky down, and chomp him.
-- One death ends the run.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8 = memory.read_u8 or memory.readbyte

-- ---------------------------------------------------------------------------
-- Memory map (NES Pac-Man — derived from the Namco FDS RAM map)
-- Source: Data Crystal — Pac-Man (NES, FDS) / RAM map
-- https://datacrystal.tcrf.net/wiki/Pac-Man_(NES,_Famicom_Disk_System)/RAM_map
-- ---------------------------------------------------------------------------
local SCORE_TENS         = 0x0070
local SCORE_HUNDREDS     = 0x0071
local SCORE_THOUSANDS    = 0x0072
local SCORE_TENTHOUSANDS = 0x0073
local SCORE_HUNTHOUSANDS = 0x0074
local SCORE_MILLIONS     = 0x0075

local LIVES    = 0x0067
local BLINKY_X = 0x001E
local BLINKY_Y = 0x0020

local function read_score()
    return read_u8(SCORE_TENS)         * 10
         + read_u8(SCORE_HUNDREDS)     * 100
         + read_u8(SCORE_THOUSANDS)    * 1000
         + read_u8(SCORE_TENTHOUSANDS) * 10000
         + read_u8(SCORE_HUNTHOUSANDS) * 100000
         + read_u8(SCORE_MILLIONS)     * 1000000
end

-- ---------------------------------------------------------------------------
-- Ghost-eaten detection — Data Crystal does NOT document a ghost-state
-- byte for the FDS port, so we infer the eat from two signals on the
-- same frame:
--
--   1. Score delta is exactly 200, 400, 800, or 1600 (the only values
--      a single-frame ghost-eat can produce in arcade-faithful Pac-Man).
--   2. Blinky's coordinates teleport — when eaten, the ghost snaps to
--      the ghost-house spawn point. Normal movement is 1px/frame; an
--      eat-event teleport is hundreds of pixels. A 16px threshold is
--      well above ghost movement and well below the smallest possible
--      teleport-on-eat.
--
-- The combination is what makes it Blinky-specific: ANY ghost being
-- eaten triggers the score event, but only the eaten ghost teleports.
-- ---------------------------------------------------------------------------
local GHOST_EAT_SCORE_DELTAS = { [200] = true, [400] = true, [800] = true, [1600] = true }
local TELEPORT_THRESHOLD     = 16

-- Per-attempt baselines (set in setup() so retries reset cleanly).
local prev_score    = 0
local prev_blinky_x = 0
local prev_blinky_y = 0
local prev_lives    = 0

challenge.run{
    savestate = "savestates/eat-blinky.State",
    expected_rom_hashes = {},
    countdown = false,

    setup = function(state)
        emu.frameadvance()
        prev_score    = read_score()
        prev_blinky_x = read_u8(BLINKY_X)
        prev_blinky_y = read_u8(BLINKY_Y)
        prev_lives    = read_u8(LIVES)
    end,

    win = function()
        local cur_score    = read_score()
        local cur_blinky_x = read_u8(BLINKY_X)
        local cur_blinky_y = read_u8(BLINKY_Y)

        local score_delta = cur_score - prev_score
        local dx = math.abs(cur_blinky_x - prev_blinky_x)
        local dy = math.abs(cur_blinky_y - prev_blinky_y)
        local blinky_teleported = (dx > TELEPORT_THRESHOLD) or (dy > TELEPORT_THRESHOLD)

        local eaten_blinky =
            GHOST_EAT_SCORE_DELTAS[score_delta] and blinky_teleported

        -- Update baselines AFTER the check so the next frame's delta is
        -- computed against this frame.
        prev_score    = cur_score
        prev_blinky_x = cur_blinky_x
        prev_blinky_y = cur_blinky_y

        return eaten_blinky
    end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        gui.text(10,  6, "SCORE")
        hud.drawScore(48,  4, read_score(), 0)
        gui.text(10, 24, "BLINKY")
        gui.text(48, 24, string.format("%d,%d", read_u8(BLINKY_X), read_u8(BLINKY_Y)))
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
