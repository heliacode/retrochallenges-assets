-- Mario Bros. (1983 NES port) — Reach Phase 5
--
-- NO SAVESTATE. The framework reboots the core to power-on, then this
-- challenge's `setup` mashes Start to skip the title / GAME A-B select
-- screen and lands the player on Phase 1, frame 0. The 3-2-1-GO
-- countdown then plays over the paused first frame and the clock
-- starts when Mario gets control.
--
-- Win: phase counter reads 5 (cleared four phases). Fail: lost a life.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte

-- ---------------------------------------------------------------------------
-- Memory map — verified against Data Crystal's Mario Bros. RAM map.
-- https://datacrystal.tcrf.net/wiki/Mario_Bros./RAM_map
-- ---------------------------------------------------------------------------
local PHASE     = 0x0041  -- displayed phase number, 1-based
local LIVES_P1  = 0x0048  -- decrements on death

-- BCD score: 3 bytes at $0095-$0097, two digits each (high byte first).
local SCORE_HI  = 0x0095
local SCORE_MID = 0x0096
local SCORE_LO  = 0x0097

-- Mario Bros. has no documented single-byte pause flag, so we don't
-- supply freeze_game / release_game — the framework falls back to its
-- universal RAM-snapshot freeze during countdown and banners.

local function bcd(b) return math.floor(b / 16) * 10 + (b % 16) end

local function read_score()
    return bcd(read_u8(SCORE_HI))  * 10000
         + bcd(read_u8(SCORE_MID)) *   100
         + bcd(read_u8(SCORE_LO))
end

-- ---------------------------------------------------------------------------
-- Boot-to-Phase-1: alternate-frame Start presses until $0041 reads 1.
-- At power-on $0041 is 0 (or uninitialised); after Start is consumed on
-- the title screen the game initialises Phase 1 and sets it to 1. The
-- on/off alternation handles the title's edge-only Start detection.
-- ---------------------------------------------------------------------------
local function press_start_until(predicate, max_frames)
    max_frames = max_frames or 600
    for f = 0, max_frames - 1 do
        joypad.set({ Start = (f % 2 == 0) }, 1)
        emu.frameadvance()
        if predicate() then
            joypad.set({}, 1)
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Per-attempt state.
-- ---------------------------------------------------------------------------
local start_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge.
-- ---------------------------------------------------------------------------
challenge.run{
    expected_rom_hashes = { "A684D6F5E0FA39B603038F041EE6E853203B44AD" },  -- Mario Bros., iNES file SHA1

    setup = function(state)
        -- Boot delay so the title intro initialises before we send input.
        for _ = 1, 60 do emu.frameadvance() end

        local ok = press_start_until(function()
            return read_u8(PHASE) == 1
        end, 600)

        if not ok then
            console.log("[reach-phase-5] setup: failed to reach Phase 1 after 600 frames — RAM watch may show $0041 stuck at 0; check the title-screen path on this dump")
        end

        start_lives = read_u8(LIVES_P1)
    end,

    -- Win on the displayed phase rolling to 5. Bonus phases between
    -- regular phases also tick $0041, so "reach phase 5" includes any
    -- bonus-phase detours en route.
    win = function()
        return read_u8(PHASE) >= 5
    end,

    -- Fail = lost a life. Game-over screen would also satisfy this via
    -- the rollover, but the decrement edge catches it earlier.
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
