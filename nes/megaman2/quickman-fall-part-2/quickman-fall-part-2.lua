-- Mega Man 2 — QuickMan Stage fall part 2
-- Continuation of the death-laser corridor. Survive 10 vertical
-- screen transitions this time — twice the part-1 budget.
--
-- Win  = current_screen ($0038) has incremented by 10 from the
--        captured value.
-- Fail = lives counter decrements (laser hits, pits, HP zero).
--
-- Mirrors quickman-level.lua's structure; only the screen budget
-- and savestate path differ.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

local PLAYER_HP      = 0x06C0
local LIVES          = 0x00A8
local CURRENT_SCREEN = 0x0038
local DIFFICULTY     = 0x00CB
local GAME_MODE      = 0x00AA   -- bit 2 = "pause entities"

local MAX_HP             = 0x1C
local NORMAL             = 0x00
local SCREENS_TO_SURVIVE = 10

local function freeze_game()
    write_u8(GAME_MODE, 0x04)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(GAME_MODE, 0x00)
end

local prev_lives    = 0
local screen_at_start = 0

challenge.run{
    savestate           = "savestates/quickman-fall-part-2.state",
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
        gui.text(112, 12, screens .. "/" .. SCREENS_TO_SURVIVE)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
