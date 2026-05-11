-- Mario Bros. (1983 NES port) — Reach Phase 5
-- Single-life run through the arcade-style endless phases. Win when
-- the phase counter rolls to 5; fail if you drop a life along the way.
--
-- Savestate target: title screen → 1P Game A selected → first frame of
-- Phase 1 with Mario standing on the lowest platform. (We don't write
-- starting RAM — the savestate IS the starting state.)

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte

-- ---------------------------------------------------------------------------
-- Memory map (Mario Bros. — mapper 0 NROM)
-- Source: nes/mariobros/RAM.md, derived from Data Crystal.
-- ---------------------------------------------------------------------------
local PHASE     = 0x0041  -- displayed phase number, 1-based
local LIVES_P1  = 0x0048  -- decrements on death; game over when it would go below 0

-- BCD score: 3 bytes at $0095-$0097, two digits each.
local SCORE_HI  = 0x0095
local SCORE_MID = 0x0096
local SCORE_LO  = 0x0097

-- Mario Bros. doesn't have a documented single-byte pause flag — we
-- skip per-game freeze and let the framework's universal RAM-snapshot
-- fallback handle it during the countdown. (Per the MM2 regression fix:
-- only games without a known freeze byte should rely on universal.)

local function bcd(b) return math.floor(b / 16) * 10 + (b % 16) end

local function read_score()
    return bcd(read_u8(SCORE_HI))  * 10000
         + bcd(read_u8(SCORE_MID)) *   100
         + bcd(read_u8(SCORE_LO))
end

-- ---------------------------------------------------------------------------
-- Per-attempt state.
-- ---------------------------------------------------------------------------
local start_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge.
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/reach-phase-5.state",
    expected_rom_hashes = { "A684D6F5E0FA39B603038F041EE6E853203B44AD" },  -- Mario Bros., iNES file SHA1

    setup = function(state)
        emu.frameadvance()
        start_lives = read_u8(LIVES_P1)
    end,

    -- Win when the displayed phase number reaches 5 (i.e. you've cleared
    -- phases 1-4). Bonus phases between regular phases also increment
    -- $0041, so "reach phase 5" includes any bonus-phase detours.
    win = function()
        return read_u8(PHASE) >= 5
    end,

    -- Fail = lost a life. Game-over screen is also reachable via lives
    -- rollover but the decrement edge catches that first.
    fail = function()
        return read_u8(LIVES_P1) < start_lives
    end,

    hud = function(state)
        gui.text(10, 6, "PHASE")
        gui.text(48, 6, tostring(read_u8(PHASE)) .. " / 5")
        gui.text(10, 18, "SCORE")
        hud.drawScore(48, 16, read_score(), 0)
        gui.text(10, 30, "TIME")
        hud.drawTime(48, 28, state.elapsed)
    end,

    result = function(state)
        return {
            score          = read_score(),
            completionTime = state.elapsed,
        }
    end,
}
