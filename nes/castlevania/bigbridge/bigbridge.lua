-- Castlevania Cross the Big Bridge Challenge
-- Drops Simon at the start of the bridge with a loaded loadout
-- (12 hearts, axe subweapon, long whip). Win by defeating the mummy
-- boss at the end. Any death — pit, damage, instant-kill — fails the
-- run; pressing R at any moment restarts from the savestate.
--
-- Built on the RcChallenge framework. This file is just the per-game
-- knobs (memory addresses, win/fail predicates, HUD layout, the
-- USER_PAUSED freeze trick).

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES release of Castlevania)
-- ---------------------------------------------------------------------------
local USER_PAUSED  = 0x0022   -- write 1 to freeze game state in place
local LIVES        = 0x002A   -- decrements on every death cause
local HEALTH_REAL  = 0x0045   -- 0x40 = full
local HEARTS       = 0x0071   -- subweapon ammo
local SUBWEAPON    = 0x015B   -- 0x0D = axe
local WHIP_LEVEL   = 0x0070   -- 0x02 = long
local BOSS_HEALTH  = 0x01A9   -- mummy

local FULL_HEALTH    = 0x40
local START_HEARTS   = 12
local AXE_WEAPON     = 0x0D
local LONG_WHIP      = 0x02

-- ---------------------------------------------------------------------------
-- Game-specific freeze trick: writing USER_PAUSED=1 stops Castlevania's
-- own state machine while BizHawk keeps advancing emulation frames so
-- our gui.draw* keeps rendering during overlays.
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(USER_PAUSED, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(USER_PAUSED, 0)
end

-- ---------------------------------------------------------------------------
-- Per-attempt state. The fail predicate compares the lives counter to
-- whatever it was at the start of THIS attempt — set in setup() so it
-- gets re-baselined on every retry.
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate    = "savestates/bigbridge.state",
    countdown    = true,
    freeze_game  = freeze_game,
    release_game = release_game,

    -- Hand Simon his loadout. The hearts double-write (0 then 12) is a
    -- known HUD-refresh trick so the on-screen heart counter actually
    -- updates after the savestate load.
    setup = function(state)
        write_u8(HEARTS, 0)
        emu.frameadvance()
        write_u8(HEARTS, START_HEARTS)
        write_u8(SUBWEAPON, AXE_WEAPON)
        write_u8(WHIP_LEVEL, LONG_WHIP)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    win = function() return read_u8(BOSS_HEALTH) == 0 end,

    -- Lives decrement is the universal death signal — catches pit falls
    -- (which don't drain HP), damage deaths, and instant-kill traps.
    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        local simon_hp = read_u8(HEALTH_REAL)
        local boss_hp  = read_u8(BOSS_HEALTH)
        local lives    = read_u8(LIVES)

        gui.text(10,  6, "TIME")
        hud.drawTime(48,  4, state.elapsed)
        gui.text(10, 30, "HP")
        hud.drawBar(28, 32, 70, simon_hp, FULL_HEALTH, "hp")
        gui.text(10, 46, "LIVES")
        hud.drawDigits(48, 44, tostring(lives))
        gui.text(10, 70, "MUMMY")
        hud.drawDigits(48, 68, tostring(boss_hp))
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
