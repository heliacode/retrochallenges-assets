-- Mega Man 2 — Heat Man Stage: The Floor Is Lava
-- The infamous disappearing-block stretch over an instakill pit. No
-- subweapons, no Item-2 (jet sled) cheese — just the buster, full HP,
-- and patience. Reach the bottom of the descent ladder alive and the
-- challenge wins.
--
-- Win  = $0038 (current_screen) advances past whatever it was at the
--        savestate's start. The descent ladder takes Mega Man into the
--        next vertical room, which bumps the screen index.
-- Fail = lives counter decrements. Catches both HP-zero damage deaths
--        AND the instakill pit drops that bypass HP entirely (lava
--        tiles in MM2 set $0032 = 0x03 and just kill you outright).
--
-- Built on RcChallenge — savestate, countdown, win banner, leaderboard
-- submission, R-anywhere-to-retry come from the framework.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Mega Man 2)
-- See nes/megaman2/RAM.md for the full reference.
-- ---------------------------------------------------------------------------
local PLAYER_HP       = 0x06C0
local LIVES           = 0x00A8
local CURRENT_WEAPON  = 0x00A9
local DIFFICULTY      = 0x00CB
local GAME_MODE       = 0x00AA   -- bit 2 = "pause entities"
local CURRENT_SCREEN  = 0x0038   -- room/screen index within the stage

local MAX_HP = 0x1C   -- 28
local BUSTER = 0x00
local NORMAL = 0x00

-- ---------------------------------------------------------------------------
-- Freeze trick (same MM2 pattern as the boss fights).
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(GAME_MODE, 0x04)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(GAME_MODE, 0x00)
end

-- ---------------------------------------------------------------------------
-- Per-attempt state — lives baseline for death detection + the screen
-- snapshot for the descent-detector.
-- ---------------------------------------------------------------------------
local prev_lives    = 0
local start_screen  = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/heatman-the-floor-is-lava.state",
    expected_rom_hashes = { "2290D8D839A303219E9327EA1451C5EEA430F53D" },  -- Mega Man 2 (USA, iNES file SHA1)

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        write_u8(PLAYER_HP,      MAX_HP)
        write_u8(CURRENT_WEAPON, BUSTER)
        write_u8(DIFFICULTY,     NORMAL)
        emu.frameadvance()
        prev_lives   = read_u8(LIVES)
        start_screen = read_u8(CURRENT_SCREEN)
    end,

    -- Win once Mega Man transitions to the screen below. $0038 ticks
    -- on every screen boundary so any change away from the captured
    -- starting screen counts — the only legal direction out of the
    -- savestate's screen is down the ladder, so we don't need to gate
    -- on direction.
    win = function() return read_u8(CURRENT_SCREEN) ~= start_screen end,

    -- Lives decrement is the universal MM2 death signal — covers both
    -- HP-zero damage AND instakill pit drops (which skip the HP bar
    -- entirely on lava tiles).
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
