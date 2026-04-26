-- TEMPLATE: copy this file into nes/<game>/<challenge>/<challenge>.lua and
-- fill in the per-game bits. Everything not edited stays the same as
-- every other challenge — that's the point.
--
-- The RcChallenge framework handles:
--   - Memory-domain selection
--   - Savestate load (with a "missing savestate" fallback screen)
--   - 3-2-1-GO countdown (uses shared assets/3.png, 2.png, 1.png, go.png)
--   - Play loop with HUD callback
--   - Win path: 60-frame post-win delay, leaderboard submission, banner
--   - Fail path (optional): banner + retry prompt
--   - Universal R-to-retry at ANY moment during the run
--
-- You provide:
--   - Memory addresses for your game
--   - Win predicate (and optionally fail predicate)
--   - HUD callback drawing time / score / whatever the player should see
--   - Result builder for the leaderboard payload
--   - Optional setup callback (write a starting loadout / etc.)
--   - Optional freeze_game / release_game (game-specific pause trick;
--     without these, the game keeps animating under the countdown / win
--     banners, which is usually fine)

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Per-game memory map. Replace these with your game's RAM addresses.
-- ---------------------------------------------------------------------------
local ADDR = {
    -- e.g. SCORE = 0x07FC, BOSS_HEALTH = 0x01A9, ...
}

-- Replace with your challenge's target value.
local TARGET_SCORE = 5000

-- ---------------------------------------------------------------------------
-- Optional: per-game freeze trick. Castlevania writes 1 to USER_PAUSED
-- (0x0022) to stop the game while emulation keeps advancing frames so
-- gui.draw* keeps rendering. Other games will need different bytes; if
-- you don't have one, leave both as no-ops.
-- ---------------------------------------------------------------------------
local function freeze_game()
    -- write_u8(0x0022, 1)
    -- joypad.set({}, 1)  -- neutralize input while frozen
end

local function release_game()
    -- write_u8(0x0022, 0)
end

-- ---------------------------------------------------------------------------
-- Optional helpers (remove if your challenge doesn't need them).
-- ---------------------------------------------------------------------------
local function read_score()
    -- BCD example (Castlevania-style): three BCD bytes, 6 displayed digits.
    -- local function bcd(b) return math.floor(b/16)*10 + (b%16) end
    -- return bcd(read_u8(ADDR.SCORE))*10000
    --      + bcd(read_u8(ADDR.SCORE+1))*100
    --      + bcd(read_u8(ADDR.SCORE+2))
    return 0
end

-- ---------------------------------------------------------------------------
-- Run the challenge. Every field except `savestate` and `win` is optional.
-- ---------------------------------------------------------------------------
challenge.run{
    savestate = "savestates/<challenge>.state",

    setup = function(state)
        -- Re-run on every (re)start. Write any starting RAM state here:
        -- write_u8(ADDR.HEARTS, 12)
        -- write_u8(ADDR.SUBWEAPON, 0x0D)
    end,

    freeze_game  = freeze_game,
    release_game = release_game,

    win = function(state)
        return read_score() >= TARGET_SCORE
    end,

    -- Optional: omit this entirely for challenges where you can't fail.
    -- For death-detection use the lives counter (decrements on any death
    -- cause — pit, HP zero, instant-kill — see Castlevania bigbridge):
    --   fail = function(state) ... end,

    hud = function(state)
        gui.text(10, 6, "SCORE")
        hud.drawScore(48, 4, read_score(), TARGET_SCORE)
        gui.text(10, 24, "TIME")
        hud.drawTime(48, 22, state.elapsed)
    end,

    result = function(state)
        return {
            score          = read_score(),
            completionTime = state.elapsed,
        }
    end,
}
