-- FlawlessNES — Castlevania Axe Knight Stairs, No Damage
-- ======================================================
-- Survive the axe-throwing knight and climb the stairs out — without taking
-- a hit. FlawlessNES rules: you don't FAIL on a hit; every hit chips your
-- score per the fixed table (identical for every FlawlessNES challenge):
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
--   Win  = Simon climbs the stairs — the engine's Floor byte ($0046)
--          increments past its captured start value (a completed stair
--          traversal). Guarded by "lives unchanged" because a death can
--          teleport Simon to a checkpoint where $0046 reads higher, and the
--          framework checks win() before fail(); without the guard a death
--          could register as a completion (the exact bug escape-the-fish-
--          people hit).
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
local FLOOR        = 0x0046   -- Stair-floor counter; only changes on a FLOOR
                              -- transition (between-screen stairs), not the
                              -- in-screen climbing stairs in this room.
local SIMON_STATE  = 0x046C   -- Simon's state (instance 0). 0x04 = Climbing
                              -- Stairs — fires while Simon ascends/descends a
                              -- staircase, including in-screen ones.
local STATE_CLIMB  = 0x04

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
-- lives_at_start is snapshotted once and never rewritten (the win guard);
-- prev_lives is updated each frame by the fail predicate.
-- ---------------------------------------------------------------------------
local prev_lives     = 0
local lives_at_start = 0
local floor_at_start = 0
local prev_health    = 0
local hits           = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/flawlessnes-axeman-stairs.State",
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
        floor_at_start = read_u8(FLOOR)
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

    -- Win = Simon is on the stairs climbing ($046C == 0x04) AND still alive.
    -- These are in-screen stairs, so $0046 is NOT a floor counter here — it
    -- holds volatile data that changes every frame, which is why the earlier
    -- floor-change fallback false-fired on frame 0. Removed it entirely; the
    -- Climbing-Stairs state is the signal. Lives guard blocks a death-teleport.
    win = function()
        if read_u8(LIVES) < lives_at_start then return false end
        return read_u8(SIMON_STATE) == STATE_CLIMB
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
        -- TEMP DEBUG (remove once confirmed): Simon's state byte. Should read
        -- 0 standing/walking and 4 while climbing the stairs (= win).
        gui.text(10, 22, "st:" .. tostring(read_u8(SIMON_STATE)))
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
