-- Pac-Man (NES, Namco) — Eat All 4 Ghosts on One Power Pellet
-- The iconic combo: snag a power pellet, then chomp Blinky → Pinky →
-- Inky → Clyde before the frightened timer expires. One death and the
-- run is over.

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

local function read_score()
    return read_u8(SCORE_TENS)         * 10
         + read_u8(SCORE_HUNDREDS)     * 100
         + read_u8(SCORE_THOUSANDS)    * 1000
         + read_u8(SCORE_TENTHOUSANDS) * 10000
         + read_u8(SCORE_HUNTHOUSANDS) * 100000
         + read_u8(SCORE_MILLIONS)     * 1000000
end

-- ---------------------------------------------------------------------------
-- Ghost-chain detection
--
-- Each ghost in a single power-pellet chain awards 200 → 400 → 800 →
-- 1600. Eating regular dots (+10), power pellets (typically +50), and
-- fruit (100/300/500/700/1000/2000/3000/5000) doesn't collide with any
-- of those four values, so a same-frame score-delta of one of
-- {200,400,800,1600} uniquely identifies a ghost-eat.
--
-- Frightened state lasts ~6-8 seconds depending on level (480 frames
-- is a safe upper bound for stage 1). If the gap between two ghost-
-- eats exceeds that window, the player ate a fresh power pellet and
-- we restart the chain at 1.
-- ---------------------------------------------------------------------------
local GHOST_EAT_SCORE_DELTAS = { [200] = true, [400] = true, [800] = true, [1600] = true }
local CHAIN_TIMEOUT_FRAMES   = 480

-- Per-attempt state (reset in setup() so retries don't carry over).
local prev_score     = 0
local prev_lives     = 0
local chain_count    = 0
local last_eat_frame = -10000

challenge.run{
    savestate = "savestates/eat-all-4-ghosts.State",
    expected_rom_hashes = {},
    countdown = false,

    setup = function(state)
        emu.frameadvance()
        prev_score     = read_score()
        prev_lives     = read_u8(LIVES)
        chain_count    = 0
        last_eat_frame = -10000
    end,

    win = function(state)
        local cur_score = read_score()
        local delta     = cur_score - prev_score
        prev_score      = cur_score

        if GHOST_EAT_SCORE_DELTAS[delta] then
            if state.elapsed - last_eat_frame > CHAIN_TIMEOUT_FRAMES then
                chain_count = 1   -- frightened window expired; start a fresh chain
            else
                chain_count = chain_count + 1
            end
            last_eat_frame = state.elapsed
        end

        return chain_count >= 4
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
        gui.text(10, 24, "CHAIN")
        gui.text(48, 24, tostring(chain_count) .. " / 4")
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
