-- FlawlessNES — Castlevania Phantom Bat, No Damage
-- =================================================
-- No-hit fight against the Block 1 boss (Phantom Bat). FlawlessNES rules:
-- you don't FAIL on a hit — every hit chips your score per the fixed table
-- (identical for every FlawlessNES challenge):
--
--   Hits  Rank      Score
--   0     Flawless  5000
--   1     A         3500
--   2     B         2750
--   3     C         2000
--   4     D         1250
--   5+    D         1250 * 0.85^(hits-4)   (geometric decay, never 0)
--
-- A hit = Simon's real health DECREASED this frame. Death (losing a life)
-- DOES end the run. This savestate starts in the bat's boss room, so the
-- boss-engaged latch trips immediately and the win fires the moment the
-- bat's HP reaches 0.
--
-- Built on RcChallenge — savestate load, 3-2-1-GO countdown, USER_PAUSED
-- freeze, completion banner (shows SCORE), leaderboard submission, and
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
local BOSS_HEALTH  = 0x01A9   -- Boss Real Health (Phantom Bat HP)
local BOSS_SCREEN  = 0x0048   -- non-zero while a boss locks the screen

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
-- ---------------------------------------------------------------------------
local prev_lives   = 0
local prev_health  = 0
local hits         = 0
local boss_engaged = false

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/flawlessnes-batboss.State",
    expected_rom_hashes = {},  -- populate after BizHawk logs [RC] ROM SHA1
    countdown    = true,
    freeze_game  = freeze_game,
    release_game = release_game,

    -- Snapshot baselines AFTER one frame so RAM has settled. No loadout
    -- writes: a flawless run is judged on the savestate as authored.
    setup = function(state)
        emu.frameadvance()
        prev_lives   = read_u8(LIVES)
        prev_health  = read_u8(HEALTH_REAL)
        hits         = 0
        boss_engaged = false
    end,

    -- Count hits + latch boss engagement once per frame, before win/fail.
    on_frame = function(state)
        local hp = read_u8(HEALTH_REAL)
        -- A drop in real health is a hit. Castlevania's hidden meat heals
        -- (health goes UP) — we only count decreases, so heals are ignored.
        if hp < prev_health then
            hits = hits + 1
        end
        prev_health = hp

        -- Latch "boss engaged" only while a boss actually locks the screen,
        -- so leftover/garbage in the boss-HP byte can't trip the win.
        if read_u8(BOSS_SCREEN) ~= 0 and read_u8(BOSS_HEALTH) > 0 then
            boss_engaged = true
        end
    end,

    win = function()
        return boss_engaged and read_u8(BOSS_HEALTH) == 0
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
    -- rides along in the payload for forensics (kept in rawPayload).
    result = function(state)
        return {
            score          = score_for_hits(hits),
            completionTime = state.elapsed,
            hits           = hits,
            grade          = rank_for_hits(hits),
        }
    end,
}
