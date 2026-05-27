-- Castlevania 5000 Points Challenge
-- Loads a savestate that drops Simon at a known starting point and
-- measures how fast the player can score 5000 points.
--
-- Built on the RcChallenge framework — that's where the savestate-load,
-- 3-2-1-GO countdown, completion banner, leaderboard submission, and
-- universal R-anywhere-to-retry logic live. This file is just the
-- per-game knobs (memory addresses, win predicate, HUD layout).

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES release)
-- ---------------------------------------------------------------------------
-- Score is three BCD bytes, stored low-to-high:
--   $07FC = 10s + 1s digit (units always 0 in Castlevania)
--   $07FD = 1000s + 100s digit
--   $07FE = 100000s + 10000s digit (also used by the engine for 1UP checks)
--
-- 5000 lives entirely in the middle byte ($07FD = 0x50) so this challenge
-- works with either byte ordering, but get-10000-pts-fleaman exposed the
-- earlier swap. Aligning here defensively in case scores cross into the
-- high byte during an extended run.
local SCORE_ADDR  = 0x07FC
local TARGET_SCORE = 5000

-- USER_PAUSED freeze trick: writing 1 here freezes Castlevania's own
-- state machine while BizHawk keeps advancing emulation frames, so
-- gui.draw* keeps rendering during countdown / completion overlays.
local USER_PAUSED = 0x0022

-- Lives counter — used by the fail predicate to end the run on death,
-- matching every other CV challenge in this repo.
local LIVES = 0x002A
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function bcd_byte(b) return math.floor(b / 16) * 10 + (b % 16) end

local function read_score()
    local lo = bcd_byte(read_u8(SCORE_ADDR))
    local mi = bcd_byte(read_u8(SCORE_ADDR + 1))
    local hi = bcd_byte(read_u8(SCORE_ADDR + 2))
    return hi * 10000 + mi * 100 + lo
end

local function freeze_game()
    write_u8(USER_PAUSED, 1)
    joypad.set({}, 1)  -- null player input while frozen
end

local function release_game()
    write_u8(USER_PAUSED, 0)
end

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate    = "savestates/5000pts.state",
    expected_rom_hashes = { "7A20C44F302FB2F1B7ADFFA6B619E3E1CAE7B546" },  -- Castlevania (USA, iNES file SHA1)
    countdown    = true,
    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    win = function() return read_score() >= TARGET_SCORE end,

    -- Death ends the run. Watching the lives counter catches every
    -- cause (pit, enemy contact, timer-zero) uniformly. Edge-trigger
    -- on decrement so a between-frame 1-Up can't mask a later death.
    fail = function()
        local now_lives = read_u8(LIVES)
        if now_lives < prev_lives then return true end
        prev_lives = now_lives
        return false
    end,

    hud = function(state)
        gui.text(10,  6, "SCORE")
        hud.drawScore(48,  4, read_score(), TARGET_SCORE)
        gui.text(10, 28, "TIME")
        hud.drawTime(48, 26, state.elapsed)
    end,

    result = function(state)
        return {
            score          = read_score(),
            completionTime = state.elapsed,
        }
    end,
}
