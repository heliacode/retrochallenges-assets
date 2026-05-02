-- Castlevania — 10000 Points in the Fleaman Area
-- Simon spawns in stage 10 (the fleaman cavern) with a small whip,
-- no subweapon, no hearts, full HP, and 0 points. Score 10000 before
-- you die or get pushed/scrolled out of the stage.
--
-- Win  = score reaches 10000.
-- Fail = lives decrement (universal death detection — pits, damage,
--        instakill traps) OR the Stage byte ($0028) leaves its
--        captured starting value (i.e. Simon walked through a door
--        into the next stage).
--
-- Built on RcChallenge — savestate, countdown, win banner, leaderboard
-- submission, and R-anywhere-to-retry come from the framework.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Castlevania)
-- See nes/castlevania/castlevania_raminfo.md
-- ---------------------------------------------------------------------------
local USER_PAUSED  = 0x0022
local STAGE        = 0x0028
local LIVES        = 0x002A
local HEALTH_REAL  = 0x0045
local WHIP_LEVEL   = 0x0070
local HEARTS       = 0x0071
local SUBWEAPON    = 0x015B
local SCORE_ADDR   = 0x07FC   -- 3 BCD bytes: hi=$07FC, mid=$07FD, lo=$07FE

local FULL_HEALTH    = 0x40
local SHORT_WHIP     = 0x00   -- leather (starting whip)
local NO_WEAPON      = 0x00
local TARGET_SCORE   = 10000

-- ---------------------------------------------------------------------------
-- Score is three BCD bytes, stored low-to-high:
--   $07FC = 10s + 1s digit  (units always 0 in Castlevania)
--   $07FD = 1000s + 100s digit
--   $07FE = 100000s + 10000s digit  (also used by the engine for 1UP checks)
--
-- The original 5000pts challenge had this swapped, but the bug never
-- manifested at scores ≤ 9990 because the relevant digit lives in the
-- middle byte ($07FD) which is identical in either ordering. 10k breaks
-- past 9999 into the high byte and exposed the swap.
-- ---------------------------------------------------------------------------
local function bcd_byte(b) return math.floor(b / 16) * 10 + (b % 16) end

local function read_score()
    local lo = bcd_byte(read_u8(SCORE_ADDR))
    local mi = bcd_byte(read_u8(SCORE_ADDR + 1))
    local hi = bcd_byte(read_u8(SCORE_ADDR + 2))
    return hi * 10000 + mi * 100 + lo
end

-- ---------------------------------------------------------------------------
-- Game-specific freeze trick (Castlevania pause flag).
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(USER_PAUSED, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(USER_PAUSED, 0)
end

-- ---------------------------------------------------------------------------
-- Per-attempt state. Re-baselined in setup() so retries get a clean slate.
-- ---------------------------------------------------------------------------
local prev_lives     = 0
local stage_at_start = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/get-10000-pts-fleaman.state",
    expected_rom_hashes = { "7A20C44F302FB2F1B7ADFFA6B619E3E1CAE7B546" },  -- Castlevania (USA, iNES file SHA1)
    countdown           = true,
    freeze_game         = freeze_game,
    release_game        = release_game,

    -- Standardize the loadout. Score is also zeroed here in case the
    -- savestate was captured with a non-zero score.
    setup = function(state)
        write_u8(HEALTH_REAL, FULL_HEALTH)
        write_u8(WHIP_LEVEL,  SHORT_WHIP)
        write_u8(SUBWEAPON,   NO_WEAPON)
        write_u8(HEARTS,      0)
        write_u8(SCORE_ADDR,     0)
        write_u8(SCORE_ADDR + 1, 0)
        write_u8(SCORE_ADDR + 2, 0)
        emu.frameadvance()
        prev_lives     = read_u8(LIVES)
        stage_at_start = read_u8(STAGE)
    end,

    win = function() return read_score() >= TARGET_SCORE end,

    -- Death OR stage-change ends the run. The stage byte changes the
    -- frame Simon walks through a door into the next room cluster.
    fail = function()
        local now_lives = read_u8(LIVES)
        if now_lives < prev_lives then return true end
        prev_lives = now_lives
        if read_u8(STAGE) ~= stage_at_start then return true end
        return false
    end,

    hud = function(state)
        gui.text(10, 6, "TIME")
        hud.drawTime(48, 4, state.elapsed)
    end,

    result = function(state)
        return {
            score          = read_score(),
            completionTime = state.elapsed,
        }
    end,
}
