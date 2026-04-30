-- Mega Man 2 — Crash Man Boss Fight (Buster Only)
-- Loaded loadout: full HP (28), buster equipped. Defeat Crash Man as
-- fast as possible without switching weapons. Die once and the run is over.
--
-- Built on RcChallenge — savestate, countdown, win banner, leaderboard
-- submission, and R-anywhere-to-retry come from the framework.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Mega Man 2)
-- See nes/megaman2/RAM.md for the full reference.
-- ---------------------------------------------------------------------------
local PLAYER_HP      = 0x06C0
local BOSS_HP        = 0x06C1   -- shared slot for all 8 Robot Masters + Wily bosses
local LIVES          = 0x00A8
local CURRENT_WEAPON = 0x00A9
local DIFFICULTY     = 0x00CB
local GAME_MODE      = 0x00AA   -- bit 2 = "pause entities"

local MAX_HP   = 0x1C   -- 28
local BUSTER   = 0x00
local NORMAL   = 0x00   -- standardized "Difficult" mode

-- ---------------------------------------------------------------------------
-- Freeze trick: write 0x04 to game_mode to set bit 2 — entity_update_dispatch
-- short-circuits, so AI / physics / projectiles / animations all halt while
-- the renderer keeps drawing our banner. 0x00 resumes.
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(GAME_MODE, 0x04)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(GAME_MODE, 0x00)
end

-- ---------------------------------------------------------------------------
-- Per-attempt state (lives baseline for the death detector).
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/crashman-buster-only.state",
    expected_rom_hashes = { "2290D8D839A303219E9327EA1451C5EEA430F53D" },  -- Mega Man 2 (USA, iNES file SHA1)

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        write_u8(PLAYER_HP,      MAX_HP)
        write_u8(CURRENT_WEAPON, BUSTER)
        write_u8(DIFFICULTY,     NORMAL)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    win = function() return read_u8(BOSS_HP) == 0 end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        gui.drawRectangle(6, 4, 110, 28, 0xc0000000, 0xc0000000)
        hud.drawTime(10, 8, state.elapsed)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
