-- Castlevania Medusa Boss Fight
-- Loaded loadout: full HP, 49 hearts, triple-shot, holy water. Defeat
-- Medusa as fast as possible. Die once and the run is over.
--
-- Built on RcChallenge — savestate, countdown, freeze, win banner,
-- leaderboard submission, and R-anywhere-to-retry come from the framework.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Castlevania)
-- Per retrochallenges.com/guides/nes/castlevania.html
-- ---------------------------------------------------------------------------
local USER_PAUSED        = 0x0022
local LIVES              = 0x002A
local HEALTH_REAL        = 0x0045
local WEAPON_MULTIPLIER  = 0x0064   -- 1 = single, 2 = double, 3 = triple (convention; verify)
local HEARTS             = 0x0071
local SUBWEAPON          = 0x015B   -- 0x0B = Holy Water
local BOSS_HEALTH        = 0x01A9   -- Medusa HP

local FULL_HEALTH   = 0x40
local START_HEARTS  = 49
local HOLY_WATER    = 0x0B
local TRIPLE_SHOT   = 0x03

-- ---------------------------------------------------------------------------
-- Game-specific freeze trick
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(USER_PAUSED, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(USER_PAUSED, 0)
end

-- ---------------------------------------------------------------------------
-- Per-attempt state (lives baseline for the death detector).
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate    = "savestates/medusa-boss-fight.state",
    countdown    = true,
    freeze_game  = freeze_game,
    release_game = release_game,

    -- Standardize the loadout. Hearts use the double-write HUD-refresh
    -- trick (the displayed counter sometimes ignores a single direct
    -- write — going through 0 forces a redraw).
    setup = function(state)
        write_u8(HEALTH_REAL,       FULL_HEALTH)
        write_u8(HEARTS,            0)
        emu.frameadvance()
        write_u8(HEARTS,            START_HEARTS)
        write_u8(SUBWEAPON,         HOLY_WATER)
        write_u8(WEAPON_MULTIPLIER, TRIPLE_SHOT)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    win = function() return read_u8(BOSS_HEALTH) == 0 end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        local simon_hp = read_u8(HEALTH_REAL)
        local boss_hp  = read_u8(BOSS_HEALTH)
        local hearts   = read_u8(HEARTS)

        gui.text(10,  6, "TIME")
        hud.drawTime(48,  4, state.elapsed)
        gui.text(10, 30, "HP")
        hud.drawBar(28, 32, 70, simon_hp, FULL_HEALTH, "hp")
        gui.text(10, 46, "HEARTS")
        hud.drawDigits(58, 44, tostring(hearts))
        gui.text(10, 70, "MEDUSA")
        hud.drawDigits(58, 68, tostring(boss_hp))
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
