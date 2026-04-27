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
-- Score is three BCD bytes at 0x07FC. The six digits map to
-- 100000s + 10000s, 1000s + 100s, 10s + ones; the last digit is always
-- 0 in Castlevania so the displayed score is always a multiple of 10.
local SCORE_ADDR  = 0x07FC
local TARGET_SCORE = 5000

-- USER_PAUSED freeze trick: writing 1 here freezes Castlevania's own
-- state machine while BizHawk keeps advancing emulation frames, so
-- gui.draw* keeps rendering during countdown / completion overlays.
local USER_PAUSED = 0x0022

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function bcd_byte(b) return math.floor(b / 16) * 10 + (b % 16) end

local function read_score()
    local hi = bcd_byte(read_u8(SCORE_ADDR))
    local mi = bcd_byte(read_u8(SCORE_ADDR + 1))
    local lo = bcd_byte(read_u8(SCORE_ADDR + 2))
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

    win = function() return read_score() >= TARGET_SCORE end,

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
