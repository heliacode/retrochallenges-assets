-- FlawlessNES — Castlevania Mummy Bridge (reach the Mummies' arena), No Damage
-- ===========================================================================
-- Cross the bridge up to the Mummies' boss room without taking a hit.
-- FlawlessNES rules: you don't FAIL on a hit; every hit chips your score per
-- the fixed table (identical for every FlawlessNES challenge):
--
--   Hits  Rank      Score
--   0     Flawless  5000
--   1     A         3500
--   2     B         2750
--   3     C         2000
--   4     D         1250
--   5+    D         1250 * 0.85^(hits-4)   (geometric decay, never 0)
--
-- A hit = Simon's real health DECREASED this frame.
--
-- The run ends two ways:
--   Win  = the boss room is showing — i.e. the screen stops scrolling.
--          Castlevania locks scrolling for a boss via the Boss-Screen byte
--          ($0048), which reads 0 on the bridge and flips non-zero the
--          instant the arena locks. Guarded by "lives unchanged" so a death
--          can't register as a win.
--   Fail = Simon dies (lives $002A decrements).
--
-- Built on RcChallenge — savestate load, 3-2-1-GO countdown, USER_PAUSED
-- freeze, completion banner (shows GRADE), leaderboard submission, and
-- R-anywhere-to-retry all come from the framework.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Castlevania)
-- Source: https://datacrystal.tcrf.net/wiki/Castlevania_(NES)/RAM_map
-- (mirrored locally in nes/castlevania/castlevania_raminfo.md)
-- ---------------------------------------------------------------------------
local USER_PAUSED  = 0x0022   -- write 1 to freeze CV's own state machine
local LIVES        = 0x002A   -- decremented on every death cause (enemy/pit/timer)
local HEALTH_REAL  = 0x0045   -- Simon real health (0x40 = full); display copy is $0044
local BOSS_SCREEN  = 0x0048   -- non-zero while a boss locks the screen (scroll lock)

-- ---------------------------------------------------------------------------
-- FlawlessNES scoring (the fixed table, computed not hard-coded so the
-- submitted score and the leaderboard's rank derivation agree exactly).
-- ---------------------------------------------------------------------------
local function score_for_hits(h)
    if h <= 0 then return 5000 end
    if h <= 4 then return 3500 - 750 * (h - 1) end      -- 1..4 -> 3500/2750/2000/1250
    return math.floor(1250 * (0.85 ^ (h - 4)) + 0.5)    -- 5+ -> geometric decay
end

-- Rank label shown on the completion banner (mirrors the leaderboard's
-- Flawless/A/B/C/D derivation from score).
local function rank_for_hits(h)
    if h <= 0 then return "FLAWLESS" end
    if h == 1 then return "A" end
    if h == 2 then return "B" end
    if h == 3 then return "C" end
    return "D"
end

-- ---------------------------------------------------------------------------
-- Castlevania per-game freeze (USER_PAUSED byte).
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(USER_PAUSED, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(USER_PAUSED, 0)
end

-- ---------------------------------------------------------------------------
-- Per-attempt state — ALL reset in setup() so a retry starts clean.
-- lives_at_start is snapshotted once (the win guard); prev_lives is updated
-- each frame by the fail predicate.
-- ---------------------------------------------------------------------------
local prev_lives     = 0
local lives_at_start = 0
local prev_health    = 0
local hits           = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/flawlessnes-mummy-bridge.State",
    expected_rom_hashes = {},  -- populate after BizHawk logs [RC] ROM SHA1
    countdown    = true,
    freeze_game  = freeze_game,
    release_game = release_game,

    -- Snapshot baselines AFTER one frame so RAM has settled. No loadout
    -- writes: a flawless run is judged on the savestate as authored.
    setup = function(state)
        emu.frameadvance()
        prev_lives     = read_u8(LIVES)
        lives_at_start = prev_lives        -- snapshot, never updated this attempt
        prev_health    = read_u8(HEALTH_REAL)
        hits           = 0
    end,

    -- Count hits once per frame, before win/fail. A drop in real health is
    -- a hit; Castlevania's hidden meat heals (health UP), which we ignore.
    on_frame = function(state)
        local hp = read_u8(HEALTH_REAL)
        if hp < prev_health then
            hits = hits + 1
        end
        prev_health = hp
    end,

    -- Win = the screen locked for the boss (Mummies' arena showing) AND still
    -- alive. The lives guard blocks a death from registering as a win.
    win = function()
        if read_u8(LIVES) < lives_at_start then return false end
        return read_u8(BOSS_SCREEN) ~= 0
    end,

    -- Death ends the run. Lives decrement is the universal CV death signal.
    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    -- Minimal HUD: just the hit count, plain font, no background box.
    hud = function(state)
        gui.text(10, 10, "Hits: " .. tostring(hits))
    end,

    -- score IS the ranking axis for FlawlessNES (higher = fewer hits). The
    -- leaderboard derives the Flawless/A/B/C/D rank back out of it. `hits`
    -- and `grade` ride along; grade drives the grade-only completion banner.
    result = function(state)
        return {
            score          = score_for_hits(hits),
            completionTime = state.elapsed,
            hits           = hits,
            grade          = rank_for_hits(hits),
        }
    end,
}
