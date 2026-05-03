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
local PACMAN_X = 0x001A
local PACMAN_Y = 0x001C
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
-- byte for the FDS port, so we infer Blinky-specifically from two
-- same-frame signals:
--
--   1. Score delta is exactly 200, 400, 800, or 1600 (the only values
--      a single-frame ghost-eat can produce in arcade-faithful Pac-Man;
--      the value depends on chain position, not on which ghost).
--   2. On the eat frame, Blinky's coordinates are AT Pac-Man's
--      coordinates (Manhattan distance < 16px). Ghosts don't actually
--      teleport when eaten — they become eyes-only sprites that
--      animate smoothly back to the ghost house — but at the instant
--      of the score event, the collision puts them on the same tile
--      as Pac-Man. ANY ghost being eaten triggers the score event;
--      only the eaten ghost is ON Pac-Man at that frame.
-- ---------------------------------------------------------------------------
local GHOST_EAT_SCORE_DELTAS = { [200] = true, [400] = true, [800] = true, [1600] = true }
local COLLISION_THRESHOLD    = 16

-- Per-attempt baselines (set in setup() so retries reset cleanly).
local prev_score = 0
local prev_lives = 0

-- Debug state — surfaced on the HUD so we can SEE what the detector is
-- seeing when the player swears they just ate Blinky and nothing fired.
-- "delta"      = score change last frame
-- "p2b dist"   = Manhattan distance from Pac-Man to Blinky right now
-- "last eat"   = most recent score delta that matched the ghost-eat set
-- "last p2b"   = Pac-Man-to-Blinky distance at the moment of last_eat
local last_score_delta = 0
local last_eat_delta   = 0
local last_p2b_at_eat  = -1

challenge.run{
    savestate = "savestates/eat-blinky.State",
    expected_rom_hashes = {},

    setup = function(state)
        emu.frameadvance()
        prev_score       = read_score()
        prev_lives       = read_u8(LIVES)
        last_score_delta = 0
        last_eat_delta   = 0
        last_p2b_at_eat  = -1
    end,

    win = function()
        local cur_score = read_score()
        last_score_delta = cur_score - prev_score
        prev_score = cur_score

        if not GHOST_EAT_SCORE_DELTAS[last_score_delta] then
            return false
        end

        -- Score event matched a ghost-eat amount. Identify the ghost
        -- by checking which one is colocated with Pac-Man this frame.
        local px = read_u8(PACMAN_X)
        local py = read_u8(PACMAN_Y)
        local bx = read_u8(BLINKY_X)
        local by = read_u8(BLINKY_Y)
        local p2b = math.abs(px - bx) + math.abs(py - by)

        last_eat_delta  = last_score_delta
        last_p2b_at_eat = p2b

        return p2b < COLLISION_THRESHOLD
    end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        local px = read_u8(PACMAN_X)
        local py = read_u8(PACMAN_Y)
        local bx = read_u8(BLINKY_X)
        local by = read_u8(BLINKY_Y)
        local p2b_now = math.abs(px - bx) + math.abs(py - by)

        gui.text(10,   6, "SCORE")
        gui.text(48,   6, tostring(read_score()))
        gui.text(10,  24, "DELTA")
        gui.text(48,  24, tostring(last_score_delta))
        gui.text(10,  42, "P2B")
        gui.text(48,  42, tostring(p2b_now))
        gui.text(10,  60, "LAST EAT")
        gui.text(60,  60, string.format("%d  p2b=%d", last_eat_delta, last_p2b_at_eat))
        gui.text(10,  78, "TIME")
        hud.drawTime(48, 76, state.elapsed)
    end,

    result = function(state)
        return {
            score          = read_score(),
            completionTime = state.elapsed,
        }
    end,
}
