-- Castlevania — Mummy Boss Fight (whip only)
-- The two-mummy duel: Simon at full HP, no subweapon, no holy water
-- buying you time. Whip the linen out of them.
--
-- Win  = boss HP at $01A9 reaches 0
-- Fail = Simon's HP reaches 0 (per spec — instant signal, no need to
--        wait for the death animation)
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
local LIVES        = 0x002A
local HEALTH_REAL  = 0x0045
local SUBWEAPON    = 0x015B
local BOSS_HEALTH  = 0x01A9

local FULL_HEALTH  = 0x40
local NO_SUBWEAPON = 0x00

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
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/mummy-boss-fight.state",
    expected_rom_hashes = { "7A20C44F302FB2F1B7ADFFA6B619E3E1CAE7B546" },  -- Castlevania (USA, iNES file SHA1)
    countdown           = true,
    freeze_game         = freeze_game,
    release_game        = release_game,

    setup = function(state)
        write_u8(HEALTH_REAL, FULL_HEALTH)
        write_u8(SUBWEAPON,   NO_SUBWEAPON)
        emu.frameadvance()
    end,

    win = function() return read_u8(BOSS_HEALTH) == 0 end,

    fail = function() return read_u8(HEALTH_REAL) == 0 end,

    hud = function(state)
        gui.text(10, 6, "TIME")
        hud.drawTime(48, 4, state.elapsed)
        gui.text(10, 24, "BOSS")
        gui.text(48, 24, tostring(read_u8(BOSS_HEALTH)))
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
