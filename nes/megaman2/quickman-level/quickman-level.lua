-- Mega Man 2 — Quick Man Stage: Survive 5 Screens
-- The famous descending death-laser corridor. Survive 5 vertical
-- screen transitions without dying. Mega Man enters at full HP;
-- everything else (weapons, lives, position) is whatever the
-- savestate captured.
--
-- Win  = current_screen ($0038) has incremented by 5 from the
--        captured value. The byte ticks on every screen transition;
--        in the death-laser corridor those are all vertical drops.
-- Fail = lives counter decrements (universal death — covers laser
--        hits, pits, HP zero).

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Mega Man 2)
-- See nes/megaman2/RAM.md
-- ---------------------------------------------------------------------------
local PLAYER_HP      = 0x06C0
local LIVES          = 0x00A8
local CURRENT_SCREEN = 0x0038
local DIFFICULTY     = 0x00CB
local GAME_MODE      = 0x00AA   -- bit 2 = "pause entities"

local MAX_HP        = 0x1C   -- 28
local NORMAL        = 0x00
local SCREENS_TO_SURVIVE = 5

-- Freeze trick (matches the other MM2 challenges): write 0x04 to
-- game_mode to set bit 2; entity_update_dispatch short-circuits.
-- 0x00 resumes.
local function freeze_game()
    write_u8(GAME_MODE, 0x04)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(GAME_MODE, 0x00)
end

-- ---------------------------------------------------------------------------
-- Per-attempt state
-- ---------------------------------------------------------------------------
local prev_lives    = 0
local screen_at_start = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/quickman-level.state",
    expected_rom_hashes = { "2290D8D839A303219E9327EA1451C5EEA430F53D" },  -- Mega Man 2 (USA, iNES file SHA1)

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        write_u8(PLAYER_HP,  MAX_HP)
        write_u8(DIFFICULTY, NORMAL)
        emu.frameadvance()
        prev_lives       = read_u8(LIVES)
        screen_at_start  = read_u8(CURRENT_SCREEN)
    end,

    win = function()
        local now = read_u8(CURRENT_SCREEN)
        -- Use modular subtraction so a low-byte wrap doesn't trip the win.
        return ((now - screen_at_start) % 256) >= SCREENS_TO_SURVIVE
    end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        local screens = (read_u8(CURRENT_SCREEN) - screen_at_start) % 256
        gui.drawRectangle(6, 4, 158, 28, 0xc0000000, 0xc0000000)
        hud.drawTime(10, 8, state.elapsed)
        gui.text(118, 12, screens .. "/" .. SCREENS_TO_SURVIVE)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
